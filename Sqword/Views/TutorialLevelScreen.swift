//
//  TutorialLevelScreen.swift
//  Sqword
//
//  Created by kevin nations on 10/4/25.
//

import SwiftUI
import Combine

struct TutorialLevelScreen<BoardOverlay: View>: View {
	let title: String
	let streak: Int
	let order: Int
	let dictionaryName: String
	let showHelpers: Bool
	let onFirstPlacement: () -> Void
	let onSecondPlacement: () -> Void
	let onRequestBoosts: () -> Void
	let onWin: () -> Void
	let fixedRows: [String]? = nil   // ← pass ["AT","TO"] for L1 if you ever want to override

	// Caller-provided overlay content rendered over the board zone
	let overlay: BoardOverlay
	@Binding var l1Step: L1Step

	init(
		title: String,
		streak: Int,
		order: Int,
		dictionaryName: String,
		showHelpers: Bool,
		l1Step: Binding<L1Step>,
		onFirstPlacement: @escaping () -> Void,
		onRequestBoosts: @escaping () -> Void,
		onWin: @escaping () -> Void,
		onSecondPlacement: @escaping () -> Void = {},
		@ViewBuilder overlay: () -> BoardOverlay = { EmptyView() }
	) {
		self.title = title
		self.streak = streak
		self.order = order
		self.dictionaryName = dictionaryName
		self.showHelpers = showHelpers
		self._l1Step = l1Step
		self.onFirstPlacement = onFirstPlacement
		self.onSecondPlacement = onSecondPlacement
		self.onRequestBoosts = onRequestBoosts
		self.onWin = onWin
		self.overlay = overlay()
	}

	@State private var model = MiniSquareGame()
	@State private var didPlaceOnce = false
	// Drag state shared between bag + ghost
	@State private var draggingChar: Character? = nil
	@State private var dragPoint: CGPoint = .zero
	@State private var tutorialTileSide: CGFloat = 56     // keep bag tiles visually in sync
	@State private var boardRectInStage: CGRect = .zero
	@State private var bagRectInStage: CGRect = .zero
	@State private var fixedSolution: [String] = []
	@State private var didFireSecondPlacement = false
    @Environment(\.dismiss) private var dismiss

    private var isPad: Bool { UIDevice.current.userInterfaceIdiom == .pad }


	// MARK: - L1 one-step-at-a-time instructions

	/// Call this **after a successful bag→board placement**.
	private func updateL1StepAfterPlacement() {
		// Gate to Tutorial L1
		guard order == 2 && showHelpers else { return }

		let placed = model.board.reduce(0) { $0 + $1.compactMap { $0 }.count }

		if placed >= 2 {
			l1Step = .promptBoost
		} else if placed == 1, l1Step == .placeFirst {
			l1Step = .explainCost
		}
	}

	// Convert a finger point → board coord (or nil if in gap/outside)
	private func coordAt(_ point: CGPoint, cell: CGFloat, gap: CGFloat, order: Int) -> (r: Int, c: Int)? {
		let rect = boardRectInStage
		guard rect.contains(point) else { return nil }
		let x = point.x - rect.minX
		let y = point.y - rect.minY
		let step = cell + gap

		let c = Int(floor(x / step))
		let r = Int(floor(y / step))
		guard r >= 0, c >= 0, r < order, c < order else { return nil }

		// Inside the cell (not the gap)?
		let xInCell = x - CGFloat(c) * step
		let yInCell = y - CGFloat(r) * step
		guard xInCell <= cell && yInCell <= cell else { return nil }
		return (r, c)
	}

	// tweak if your real board uses different values
	private let refGap: CGFloat = 1
	private let minCell: CGFloat = 36
	private let maxCell: CGFloat = 120
	private let horizontalPadding: CGFloat = 16

	// Use fixed rows to seed the tutorial board/bag/solution
	private func loadFixed(_ rows: [String]) {
		let n = rows.count
		let up = rows.map { $0.uppercased() }

		fixedSolution = up
		model.order   = n            // 👈 make the engine 2×2 or 3×3 to match
		model.solution = up                          // ← IMPORTANT so revealOne() knows what to place
		model.moves = 0
		model.locked.removeAll()
		model.board = Array(repeating: Array(repeating: nil, count: n), count: n)
		model.bag = Array(up.joined())
		model.bag.shuffle()
	}

	private func isSolvedFixed() -> Bool {
		guard !fixedSolution.isEmpty else { return model.isSolved }
		for r in 0..<fixedSolution.count {
			let row = model.board[r].compactMap { $0 }
			if row.count != fixedSolution.count || String(row) != fixedSolution[r] { return false }
		}
		return true
	}

	var body: some View {
        
		ZStack {
            
			VStack(spacing: 0) {
				// HUD (top-right)
				HStack {
					Spacer()
					//Text("Moves: \(model.moves)    Streak: \(streak)")
					Text("Moves: \(model.moves)")
                        .font(.system(size: isPad ? 22 : 22, weight: .heavy, design: .rounded))
                        .tracking(2)
                        .foregroundColor(.white)
                        .opacity(0.8)
                        .frame(maxWidth: .infinity, alignment: .trailing)
				}
                
				.padding(.horizontal, horizontalPadding)
				.padding(.top, 34)
				.fixedSize(horizontal: false, vertical: true)

				// BOARD ZONE: cap to a 3×3 footprint, keep tile size = real 4×4
				GeometryReader { geo in
					// 1) Compute tile size from width as if rendering a 4×4 board
					let usableWidth = geo.size.width - horizontalPadding * 2
					let refCell = clamp(((usableWidth - 3 * refGap) / 4).rounded(.down),
										min: minCell, max: maxCell)

					// 2) Reserve only a 3×3 footprint for the tutorial zone
					let zoneWidth4  = refCell * 4 + refGap * 3   // full width feel
					let zoneHeight3 = refCell * 3 + refGap * 2   // height capped to 3×3

					ZStack(alignment: .top) {
						// Invisible board zone (positions everything)
						Color.clear
							.frame(width: zoneWidth4, height: zoneHeight3)
							.overlay(alignment: .center) {
								// 2×2 or 3×3 board, centered, using SAME tile size
								MiniBoardView(
									model: $model,
									order: order,
									cell: refCell,
									gap: refGap,
									onAnyMove: { _ in
										// Count placed tiles and fire milestones
										let placed = model.board.reduce(0) { $0 + $1.compactMap { $0 }.count }

										if !didPlaceOnce && placed >= 1 {
											didPlaceOnce = true
											onFirstPlacement()
										}
										if !didFireSecondPlacement && placed >= 2 {
											didFireSecondPlacement = true
											onSecondPlacement()   // default no-op
										}

										if isSolvedFixed() {
											DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { onWin() }
										}
									},
									// board ↔ bag drag/ghost wiring
									bagRectInStage: bagRectInStage,
									boardRectInStage: boardRectInStage,
									onBoardDragBegan: { ch, pt in
										if draggingChar == nil { draggingChar = ch }
										dragPoint = pt
									},
									onBoardDragChanged: { pt in
										dragPoint = pt
									},
									onBoardDragEnded: { _, _ in
										draggingChar = nil
									}
								)
								.id(order)
								// keep tutorial visuals aligned to board tile size
								.onAppear { tutorialTileSide = refCell }
								.onChange(of: geo.size) { _ in tutorialTileSide = refCell }
								// measure the board frame in the shared "stage" space (for drop hit-testing)
								.background(
									GeometryReader { g in
										Color.clear
											.onAppear  { boardRectInStage = g.frame(in: .named("stage")) }
											.onChange(of: g.size) { _ in
												boardRectInStage = g.frame(in: .named("stage"))
											}
									}
								)
							}
							.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                            .padding(.top, isPad ? 150 : 0)

						// Caller overlay drawn over the board zone
						overlay
							.allowsHitTesting(false)
							.transition(.opacity)
							.zIndex(1)
					}
					.frame(maxWidth: .infinity, alignment: .top)
					.padding(.horizontal, horizontalPadding)
					// 3) Constrain the whole block to the 3×3 height
					.frame(height: zoneHeight3)
				}
				.padding(.top, 14)

				// LETTER BAG
				VStack(alignment: .leading, spacing: 8) {
                    Text("Letter Bag")
                        .font(.system(size: isPad ? 22 : 22, weight: .heavy, design: .rounded))
                        .tracking(2)
                        .foregroundColor(.white)
                        .opacity(0.8)
                        .frame(maxWidth: .infinity, alignment: .leading)

					// --- Wrapping grid (replaces HStack) ---
                    let tileSide: CGFloat = isPad ? 80 : 42
                    let tileSpacing: CGFloat = 6
					let cols = [GridItem(.adaptive(minimum: tileSide, maximum: tileSide), spacing: tileSpacing)]

					LazyVGrid(columns: cols, alignment: .leading, spacing: tileSpacing) {
						ForEach(Array(model.bag.enumerated()), id: \.offset) { _, ch in
							Text(String(ch))
								.font(.system(size: isPad ? 40 : 20, weight: .heavy))
								.frame(width: tileSide, height: tileSide)
								.background(
									RoundedRectangle(cornerRadius: 8)
										.fill(Color(.secondarySystemBackground))
										.overlay(RoundedRectangle(cornerRadius: 8).stroke(.secondary, lineWidth: 1))
								)
								.contentShape(Rectangle())
								// 🚀 Immediate drag (no long-press), same as before
								.gesture(
									DragGesture(minimumDistance: 0, coordinateSpace: .named("stage"))
										.onChanged { v in
											if draggingChar == nil { draggingChar = ch }
											dragPoint = v.location
										}
										.onEnded { v in
											let pt   = v.location
											let rect = boardRectInStage
											if rect.contains(pt) {
												let x = pt.x - rect.minX
												let y = pt.y - rect.minY
												let step = tutorialTileSide + refGap
												let c = Int(floor(x / step))
												let r = Int(floor(y / step))
												let xInCell = x - CGFloat(c) * step
												let yInCell = y - CGFloat(r) * step
												if r >= 0, c >= 0, r < order, c < order,
												   xInCell <= tutorialTileSide, yInCell <= tutorialTileSide {

													// Bag → board: neutralize move cost
													let prevMoves = model.moves
													let moved = model.place(ch, at: .init(r: r, c: c))
													if moved { model.moves = prevMoves }

													if moved {
														updateL1StepAfterPlacement()
														if !didPlaceOnce {
															didPlaceOnce = true
															onFirstPlacement()
														}
														if isSolvedFixed() {
															DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { onWin() }
														}
													}
												}
											}
											draggingChar = nil
										}
								)
						}
					}
					.frame(maxWidth: .infinity, alignment: .topLeading)
					// Keep measuring the whole bag area for board→bag drop logic
					.background(
						GeometryReader { g in
							Color.clear
								.onAppear  { bagRectInStage = g.frame(in: .named("stage")) }
								.onChange(of: g.size) { _ in
									bagRectInStage = g.frame(in: .named("stage"))
								}
						}
					)
				}
				.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
				.padding(EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 0))
			}
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background {
                Image("Sqword-Splash")
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
                    .ignoresSafeArea()
                    .allowsHitTesting(true)
            }

			// 🟣 Floating ghost that follows the finger while dragging from the bag
			if let ch = draggingChar {
				Text(String(ch))
					.font(.system(size: 24, weight: .heavy))
					.frame(width: tutorialTileSide, height: tutorialTileSide)
					.background(
						RoundedRectangle(cornerRadius: 10)
							.fill(Color(.secondarySystemBackground))
							.overlay(RoundedRectangle(cornerRadius: 10).stroke(.secondary, lineWidth: 1))
					)
					.shadow(radius: 6, x: 0, y: 4)
					.position(dragPoint)    // in "stage" space
					.allowsHitTesting(false)
					.transition(.opacity)
			}
            
            HStack{

                Button { dismiss() }
                label: {
                    HStack(spacing: 8) {
                        Image(systemName: "chevron.left").imageScale(.medium)
                    }
                    .foregroundStyle(.primary)
                }
                .buttonStyle(SoftRaisedPillStyle(height: 40))
                .opacity(0.5)
                .frame(width: 60)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .safeAreaPadding(.top)      // adds the device's top safe area
                .padding(.top, 40)          // + your extra nudge
                .padding(.leading, 16)
                      
                Spacer()

                Text("TUTORIAL")
                    .font(.system(size: isPad ? 50 : 24, weight: .heavy, design: .rounded))
                    .tracking(3)
                    .foregroundColor(.white)
                    .opacity(0.5)
                    .safeAreaPadding(.top)
                    .padding(.top, 44)
                    .frame(maxHeight: .infinity, alignment: .top)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .offset(x: isPad ? -150 : -45, y: isPad ? -30 : 0)

                Color.clear.frame(width: 60)
            }
            .ignoresSafeArea(edges: .top)
            .navigationBarBackButtonHidden(true)
            
		}
		// shared coordinate space so bag drag points and board measurement agree
		.coordinateSpace(name: "stage")

		.onChange(of: l1Step) { _, new in
			if new == .promptBoost, order == 2, showHelpers {
				UIImpactFeedbackGenerator(style: .light).impactOccurred()
			}
		}

		// Seed tutorial solution once
		.onAppear {
			// Hard-coded tutorial squares
			let rows: [String]
			switch order {
			case 2: rows = ["AT", "TO"]                 // Level 1 (2×2)
			case 3: rows = ["APE", "PEN", "END"]        // Level 2 (3×3)
			default: rows = []
			}
			model.order = rows.count   // 👈 extra safety (matches L2=3)
			loadFixed(rows)            // seeds board + bag + solution

			// Initialize the one-line helper flow for Level 1
			if order == 2 && showHelpers {
				l1Step = .placeFirst
			} else {
				l1Step = .done
			}
		}

		// Listen for the tutorial Boosts panel "Reveal" action
		.onReceive(NotificationCenter.default.publisher(for: .tutorialRevealRequested)
					.receive(on: RunLoop.main)) { _ in
			withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
				model.revealOne()
			}

			if isSolvedFixed() {
				DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { onWin() }
			}

			if order == 2 && showHelpers {
				l1Step = .done
			}
		}
	}


	// Keep helpers at struct scope
	private func clamp(_ v: CGFloat, min lo: CGFloat, max hi: CGFloat) -> CGFloat {
		max(lo, min(v, hi))
	}

	// MARK: - Mini engine

	private struct MiniSquareGame {
		struct Cell: Hashable { var r: Int; var c: Int }
		
		private enum Source {
			case bag
			case board(Cell)   // move from this cell
		}
		
		var order: Int = 2
		var solution: [String] = []
		var board: [[Character?]] = []
		var locked: Set<Cell> = []        // for reveal/lock
		var bag: [Character] = []
		var moves: Int = 0

		var isSolved: Bool {
			guard board.count == order else { return false }
			for r in 0..<order {
				for c in 0..<order {
					guard let ch = board[r][c] else { return false }
					let want = Array(solution[r])[c]
					if ch != want { return false }
				}
			}
			return true
		}
		
		mutating func load(order: Int, dictionaryName: String) {
			self.order = order
			// Try bundle text (one word square per line, e.g., "APE,PEA,EAR")
			if let squares = loadSquaresFromBundle(named: dictionaryName), let pick = squares.randomElement() {
				solution = pick
			} else {
				solution = fallbackSquare(order: order)
			}

			board = Array(repeating: Array(repeating: nil, count: order), count: order)
			locked.removeAll()

			// bag is the multiset of solution letters
			bag = solution.flatMap { Array($0) }.shuffled()
			moves = 0
		}

		mutating func place(_ ch: Character, at cell: Cell) -> Bool {
			guard locked.contains(cell) == false else { return false }
			guard let idx = bag.firstIndex(of: ch) else { return false }

			// Take the letter from the bag
			bag.remove(at: idx)

			// If the cell had a tile, put that tile back into the bag
			if let displaced = board[cell.r][cell.c] {
				bag.append(displaced)
				moves += 1     // replacing counts as a move (callers can neutralize if needed)
			} else {
				moves += 1     // first-time placement; callers can neutralize for bag→board
			}

			// Place the new letter
			board[cell.r][cell.c] = ch
			return true
		}


		mutating func clear(at cell: Cell) {
			guard locked.contains(cell) == false else { return }
			if let ch = board[cell.r][cell.c] {
				bag.append(ch)
				board[cell.r][cell.c] = nil
				moves += 1
			}
		}

		mutating func revealOne() {
			// Bounds sanity
			let n = min(order, board.count, solution.count)
			guard n > 0 else { return }

			// Helper: find a viable source for `want` (bag preferred, else an UNLOCKED, MISPLACED board copy)
			func sourceFor(_ want: Character, avoiding target: Cell) -> Source? {
				if let _ = bag.firstIndex(of: want) { return .bag }
				for r in 0..<board.count {
					for c in 0..<board[r].count {
						guard let ch = board[r][c], ch == want else { continue }
						let cell = Cell(r: r, c: c)
						if locked.contains(cell) { continue }                   // can’t move locked
						// already correct where it sits?
						if r < solution.count {
							let rowChars = Array(solution[r])
							if c < rowChars.count, rowChars[c] == ch { continue }
						}
						if cell == target { continue }                          // trivial
						return .board(cell)
					}
				}
				return nil
			}

			// Build only *viable* placements: (target, source)
			var emptyPlacements: [(Cell, Source)] = []
			var wrongPlacements: [(Cell, Source)] = []

			for r in 0..<n {
				let rowChars = Array(solution[r])
				let cols = min(n, board[r].count, rowChars.count)
				for c in 0..<cols {
					let cell = Cell(r: r, c: c)
					let want = rowChars[c]
					if board[r][c] == nil {
						if let src = sourceFor(want, avoiding: cell) {
							emptyPlacements.append((cell, src))
						}
					} else if board[r][c]! != want && !locked.contains(cell) {
						if let src = sourceFor(want, avoiding: cell) {
							wrongPlacements.append((cell, src))
						}
					}
				}
			}

			guard let (target, source) = emptyPlacements.randomElement() ?? wrongPlacements.randomElement() else {
				#if DEBUG
				print("revealOne(): no viable targets with available source")
				#endif
				return
			}

			// Apply the move without duplicating tiles
			let want = Array(solution[target.r])[target.c]

			switch source {
			case .bag:
				if let idx = bag.firstIndex(of: want) { bag.remove(at: idx) }   // consume 1 from bag
			case .board(let src):
				board[src.r][src.c] = nil                                       // vacate misplaced copy
			}

			// If target had a wrong letter, return it to the bag
			if let displaced = board[target.r][target.c], displaced != want {
				bag.append(displaced)
			}

			board[target.r][target.c] = want
			locked.insert(target)
			moves += 1

			#if os(iOS)
			UIImpactFeedbackGenerator(style: .light).impactOccurred()
			#endif
		}


		// MARK: loading helpers
		private func loadSquaresFromBundle(named: String) -> [[String]]? {
			guard let url = Bundle.main.url(forResource: named, withExtension: "txt"),
				  let text = try? String(contentsOf: url) else { return nil }
			// each non-empty line: words separated by comma or whitespace
			let lines = text.split(whereSeparator: \.isNewline)
			let squares: [[String]] = lines.compactMap { line in
				let parts = line.split { ", \t".contains($0) }.map { String($0).uppercased() }
				let n = parts.first?.count ?? 0
				guard n > 0, parts.count == n, parts.allSatisfy({ $0.count == n }) else { return nil }
				return parts
			}
			return squares.isEmpty ? nil : squares
		}

		private func fallbackSquare(order: Int) -> [String] {
			if order == 2 {
				return ["AT","TO"] // classic 2×2
			} else {
				let options = [
					["APE","PEA","EAR"],
					["EAT","ARE","TEA"]
				]
				return options.randomElement()!
			}
		}
	}

	// MARK: - Mini Board UI
	private struct MiniBoardView: View {
		@Binding var model: MiniSquareGame
		let order: Int
		let cell: CGFloat           // exact tile side
		let gap: CGFloat            // same gap as real board
		var onAnyMove: (_ didMove: Bool) -> Void

		// Pass these from the parent (measured in .named("stage"))
		var bagRectInStage: CGRect? = nil
		var boardRectInStage: CGRect? = nil

		// (optional) ghost hooks for board drags
		var onBoardDragBegan: ((Character, CGPoint) -> Void)? = nil
		var onBoardDragChanged: ((CGPoint) -> Void)? = nil
		var onBoardDragEnded: ((Character, CGPoint) -> Void)? = nil

		var body: some View {
			let boardSize = cell * CGFloat(order) + gap * CGFloat(order - 1)
			let cols = Array(repeating: GridItem(.fixed(cell), spacing: gap), count: order)
			let ready = model.board.count == order && model.board.allSatisfy { $0.count == order }
			let corner: CGFloat = 12

			LazyVGrid(columns: cols, spacing: gap) {
				ForEach(0..<(order * order), id: \.self) { i in
					let r = i / order
					let c = i % order
					let chOpt = safeChar(r, c)
					let isLocked = ready && model.locked.contains(.init(r: r, c: c))

					// ⬇️ Styled cell well + your tile content on top
					ZStack {
						// Board well (always visible)
						RoundedRectangle(cornerRadius: corner)
							.fill(Color.softSandSat)
							.softRaised(corner: corner)
							.overlay(
								RoundedRectangle(cornerRadius: corner)
									.stroke(Color.black.opacity(0.22), lineWidth: 1)
							)
							.overlay(
								RoundedRectangle(cornerRadius: corner)
									.inset(by: 0.5)
									.stroke(Color.white.opacity(0.55), lineWidth: 0.5)
									.blendMode(.overlay)
							)

						// Inner TILE only when there’s a letter
						if let ch = chOpt {
							let tileCorner: CGFloat = 12

							ZStack {
								// White tile (or green when locked)
								RoundedRectangle(cornerRadius: tileCorner)
									.fill(isLocked ? Color.green : Color(.systemBackground)) // ← white tile
									.overlay(
										RoundedRectangle(cornerRadius: tileCorner)
											.stroke(isLocked ? Color.green.opacity(0.85)
															 : Color.black.opacity(0.22),
													lineWidth: 1)
									)
									.overlay(
										RoundedRectangle(cornerRadius: tileCorner)
											.inset(by: 0.5)
											.stroke(Color.white.opacity(0.55), lineWidth: 0.5)
											.blendMode(.overlay)
									)

								// Letter
								Text(String(ch).uppercased())
									.font(.system(size: cell * 0.55, weight: .heavy))
									.foregroundStyle(isLocked ? Color.black : .primary)
									.minimumScaleFactor(0.8)
							}
							.frame(width: cell, height: cell)
							.shadow(radius: 1, x: 0, y: 1)
							.contentShape(Rectangle())
						}
					}
					.frame(width: cell, height: cell)
					.contentShape(Rectangle())

					.frame(width: cell, height: cell)
					.contentShape(Rectangle())   // so taps/drags hit even in empty areas

					// tap to clear (no move cost)
					.onTapGesture {
						guard ready, model.board[r][c] != nil else { return }
						model.board[r][c] = nil
						onAnyMove(false) // not a scoring move
					}

					// typed drop from bag — NO move cost
					.dropDestination(for: String.self) { items, _ in
						guard ready, let s = items.first, let ch = s.first else { return false }
						let prevMoves = model.moves
						let placed = model.place(ch, at: .init(r: r, c: c))
						if placed { model.moves = prevMoves }     // neutralize any move increment
						onAnyMove(placed)
						return placed
					}

					// legacy fallback (.onDrop) — NO move cost
					.onDrop(of: [.utf8PlainText, .plainText], isTargeted: nil) { providers in
						guard ready, let item = providers.first else { return false }
						_ = item.loadObject(ofClass: NSString.self) { reading, _ in
							guard let ns = reading as? NSString,
								  let ch = (ns as String).first else { return }
							DispatchQueue.main.async {
								let prevMoves = model.moves
								let placed = model.place(ch, at: .init(r: r, c: c))
								if placed { model.moves = prevMoves }
								onAnyMove(placed)
							}
						}
						return true
					}

					// 🚀 Immediate drag FROM board tile
					.gesture(
						DragGesture(minimumDistance: 0, coordinateSpace: .named("stage"))
							.onChanged { v in
								guard let ch = chOpt, ready, !isLocked else { return }
								onBoardDragBegan?(ch, v.location)
								onBoardDragChanged?(v.location)
							}
							.onEnded { v in
								guard let ch = chOpt, ready, !isLocked else { return }
								onBoardDragEnded?(ch, v.location)

								// 1) Drop over bag? → return to bag (NO move cost)
								if let bagRect = bagRectInStage, bagRect.contains(v.location) {
									model.board[r][c] = nil
									model.bag.append(ch)
									onAnyMove(false)
									return
								}

								// 2) Drop over board? → move/swap (COSTS 1 MOVE)
								guard let rect = boardRectInStage, rect.contains(v.location) else { return }
								let step = cell + gap
								let x = v.location.x - rect.minX
								let y = v.location.y - rect.minY
								let tc = Int(floor(x / step))
								let tr = Int(floor(y / step))
								guard tr >= 0, tc >= 0, tr < order, tc < order else { return }

								let xInCell = x - CGFloat(tc) * step
								let yInCell = y - CGFloat(tr) * step
								guard xInCell <= cell, yInCell <= cell else { return }

								guard tr != r || tc != c else { return }
								guard !model.locked.contains(.init(r: tr, c: tc)) else { return }

								if let destCh = model.board[tr][tc] {
									// swap
									model.board[tr][tc] = ch
									model.board[r][c]   = destCh
								} else {
									// move into empty
									model.board[tr][tc] = ch
									model.board[r][c]   = nil
								}

								model.moves += 1
								onAnyMove(true)
							}
					)
				}
			}
			.frame(width: boardSize, height: boardSize, alignment: .top)
		}

		private func safeChar(_ r: Int, _ c: Int) -> Character? {
			guard r >= 0, c >= 0,
				  r < model.board.count,
				  c < model.board[r].count else { return nil }
			return model.board[r][c]
		}
	}


	private struct TileCell: View {
		let char: Character?
		let locked: Bool
		var side: CGFloat? = nil

		var body: some View {
			let corner: CGFloat = 12

			// Resolve a font size that scales with `side` if provided
			let fontSize: CGFloat = {
				if let s = side { return max(16, s * 0.45) }
				return 24
			}()

			ZStack {
				// Base tile styling — same as your main board cells
				RoundedRectangle(cornerRadius: corner)
					.fill(Color.softSandSat)
					.softRaised(corner: corner)
					.overlay(
						RoundedRectangle(cornerRadius: corner)
							.stroke(Color.black.opacity(0.22), lineWidth: 1) // darker outer ring
					)
					.overlay(
						RoundedRectangle(cornerRadius: corner)
							.inset(by: 0.5)
							.stroke(Color.white.opacity(0.55), lineWidth: 0.5) // subtle inner highlight
							.blendMode(.overlay)
					)

				// Letter
				if let ch = char {
					Text(String(ch))
						.font(.system(size: fontSize, weight: .heavy))
						.foregroundStyle(.primary)
						.minimumScaleFactor(0.5)
				}

				// Locked overlay (keeps the same base but dims + shows a lock)
				if locked {
					RoundedRectangle(cornerRadius: corner)
						.fill(Color.black.opacity(0.06))
						.overlay(
							Image(systemName: "lock.fill")
								.font(.caption2.bold())
								.foregroundStyle(.secondary)
						)
				}
			}
			// Size rules (keep your previous behavior)
			.frame(width: side ?? nil, height: side ?? nil)
			.frame(
				minWidth: side == nil ? 56 : nil,
				maxWidth: side == nil ? 96 : nil,
				minHeight: side == nil ? 56 : nil,
				maxHeight: side == nil ? 96 : nil
			)
			.shadow(radius: 1, x: 0, y: 1)
			.contentShape(Rectangle())
		}
	}


	// MARK: - Mini bag UI (not used by default, but retained for reference)
	private struct MiniBagView: View {
		@Binding var model: MiniSquareGame

		let order: Int
		let cell: CGFloat
		let gap: CGFloat
		let boardRectInStage: CGRect

		var body: some View {
			HStack(spacing: 6) {
				ForEach(Array(model.bag.enumerated()), id: \.offset) { _, ch in
					Text(String(ch))
						.font(.system(size: 20, weight: .heavy))
						.frame(width: 42, height: 42)
						.background(
							RoundedRectangle(cornerRadius: 8)
								.fill(Color(.secondarySystemBackground))
								.overlay(RoundedRectangle(cornerRadius: 8).stroke(.secondary, lineWidth: 1))
						)
						.contentShape(Rectangle())
						.gesture(
							DragGesture(minimumDistance: 0, coordinateSpace: .named("stage"))
								.onEnded { v in
									let pt = v.location
									let rect = boardRectInStage
									guard rect.contains(pt) else { return }

									// convert point → (r,c)
									let x = pt.x - rect.minX
									let y = pt.y - rect.minY
									let step = cell + gap
									let c = Int(floor(x / step))
									let r = Int(floor(y / step))
									guard r >= 0, c >= 0, r < order, c < order else { return }

									// ensure we’re not in the gap
									let xInCell = x - CGFloat(c) * step
									let yInCell = y - CGFloat(r) * step
									guard xInCell <= cell && yInCell <= cell else { return }

									// place into the board
									_ = model.place(ch, at: .init(r: r, c: c))
								}
						)
				}
			}
			.padding(10)
			.background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
		}
	}
}

// MARK: - Notifications (file scope)

extension Notification.Name {
	static let tutorialRevealRequested = Notification.Name("tutorialRevealRequested")
}
