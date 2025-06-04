//
//  TaskBoardView.swift
//  KanbanDemo
//
//  Created by Hardik Darji on 04/06/25.
//

import SwiftUI
import UniformTypeIdentifiers


#Preview {
    TaskBoardView()
}

// MARK: - 1. Data Model
enum TaskStatus: String, Codable, CaseIterable {
    case todo = "To Do"
    case done = "Done"
}

struct Task: Identifiable, Codable, Transferable, Equatable { // <-- ADDED Equatable
    let id: UUID
    var title: String
    var description: String
    var status: TaskStatus

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .task)
    }

    static let sampleTasks: [Task] = [
        Task(id: UUID(), title: "Buy Groceries", description: "Milk, eggs, bread, fruits", status: .todo),
        Task(id: UUID(), title: "Finish Project Proposal", description: "Draft the proposal for the new project.", status: .todo),
        Task(id: UUID(), title: "Call John Doe", description: "Discuss meeting agenda.", status: .done),
        Task(id: UUID(), title: "Plan Weekend Trip", description: "Research destinations and book accommodation.", status: .todo),
        Task(id: UUID(), title: "Read 'The Martian'", description: "Finish the current book.", status: .done)
    ]
}

extension UTType {
    static var task: UTType {
        UTType(exportedAs: "com.hd.KanbanDemo")
    }
}

// MARK: - 2. TaskCardView
struct TaskCardView: View {
    let task: Task

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(task.title)
                .font(.headline)
            Text(task.description)
                .font(.subheadline)
                .foregroundColor(.gray)
        }
        .padding()
        .frame(width: 200, height: 100, alignment: .leading)
        .background(Color.white)
        .cornerRadius(10)
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
        .padding(.vertical, 5) // Keep this padding for consistent sizing
    }
}

// MARK: - Helper View: DraggableTaskItemView
struct DraggableTaskItemView: View {
    let task: Task
    @Binding var draggedTaskID: UUID?
    var onDragStart: (UUID) -> Void

    var body: some View {
        TaskCardView(task: task)
            .opacity(draggedTaskID == task.id ? 0.0 : 1.0)
            .draggable(task) {
                // Custom preview for the drag operation (optional).
                TaskCardView(task: task)
                    .frame(width: 200, height: 100)
                    .opacity(0.7)
                    .onAppear {
                        // Trigger the closure when the preview appears (i.e. drag starts)
                        onDragStart(task.id)
                    }
            }
        

    }
}

// MARK: - 3. TaskColumnView
struct TaskColumnView: View {
    let title: String
    @Binding var tasks: [Task]
    let allowedStatus: TaskStatus
    @Binding var draggedTaskID: UUID?

    // Modified signature to include targetIndex
    var onMoveTask: (Task, TaskStatus, Int) -> Void

    @State private var isTargeted: Bool = false

    var body: some View {
        VStack(alignment: .leading) {
            Text(title)
                .font(.title2)
                .fontWeight(.bold)
                .padding([.horizontal, .bottom])

            columnContent
        }
    }

    private var columnContent: some View {
        ScrollView(.vertical) {
            ForEach(tasks) { task in
                DraggableTaskItemView(task: task, draggedTaskID: $draggedTaskID) { id in
                    self.draggedTaskID = id
                }
            }
            .animation(.default, value: tasks) // ANIMATION: Animate changes to the tasks array
        }
        .frame(minWidth: 250, maxWidth: .infinity, minHeight: 200)
        .background(allowedStatus == .todo ? Color.yellow.opacity(0.1) : Color.green.opacity(0.1))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isTargeted ? Color.blue.opacity(0.5) : Color.clear, lineWidth: 3)
        )
        .dropDestination(for: Task.self) { items, location in
            if let droppedTask = items.first {
                // Calculate targetIndex based on location.y
                // TaskCardView height is 100, plus vertical padding of 5 on top and 5 on bottom = 110
                let estimatedCardTotalHeight: CGFloat = 100 + (5 * 2)
                var targetIndex = Int(location.y / estimatedCardTotalHeight)

                // Ensure targetIndex is within bounds of the current tasks array
                targetIndex = max(0, min(targetIndex, tasks.count))

                // Pass the calculated target index to the parent's move handler
                onMoveTask(droppedTask, allowedStatus, targetIndex)
                self.draggedTaskID = nil // Clear the dragged task ID after drop
                return true // Indicate that the drop was handled.
            }
            return false // Indicate that the drop was not handled.
        } isTargeted: { isTargeted in
            self.isTargeted = isTargeted
        }
    }
}

// MARK: - 4. TaskBoardView
struct TaskBoardView: View {
    @State private var todoTasks: [Task] = Task.sampleTasks.filter { $0.status == .todo }
    @State private var doneTasks: [Task] = Task.sampleTasks.filter { $0.status == .done }

    @State private var draggedTaskID: UUID?

    var body: some View {
        NavigationView {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 20) {
                    TaskColumnView(
                        title: "To Do Tasks",
                        tasks: $todoTasks,
                        allowedStatus: .todo,
                        draggedTaskID: $draggedTaskID
                    ) { droppedTask, targetStatus, targetIndex in // Pass targetIndex
                        handleTaskMovement(droppedTask: droppedTask, targetStatus: targetStatus, targetIndex: targetIndex)
                    }

                    TaskColumnView(
                        title: "Done Tasks",
                        tasks: $doneTasks,
                        allowedStatus: .done,
                        draggedTaskID: $draggedTaskID
                    ) { droppedTask, targetStatus, targetIndex in // Pass targetIndex
                        handleTaskMovement(droppedTask: droppedTask, targetStatus: targetStatus, targetIndex: targetIndex)
                    }
                }
                .padding()
            }
            .navigationTitle("Task Board")
        }
    }

    // MARK: - Task Movement Logic
    private func handleTaskMovement(droppedTask: Task, targetStatus: TaskStatus, targetIndex: Int) {
        // ANIMATION: Wrap state changes in withAnimation
        withAnimation(.default) {
            // CASE 1: Reordering within the same column
            if droppedTask.status == targetStatus {
                var listToModify: Binding<[Task]> // Use a binding to modify the correct list

                if targetStatus == .todo {
                    listToModify = $todoTasks
                } else {
                    listToModify = $doneTasks
                }

                if let sourceIndex = listToModify.wrappedValue.firstIndex(where: { $0.id == droppedTask.id }) {
                    var taskToMove = listToModify.wrappedValue.remove(at: sourceIndex)

                    // Adjust targetIndex if moving within the same list and target is after original position
                    // This accounts for the index shifting after removal.
                    var adjustedTargetIndex = targetIndex
                    if sourceIndex < adjustedTargetIndex {
                        if adjustedTargetIndex > 0 { // Prevent going below 0
                            adjustedTargetIndex -= 1
                        }
                    }
                    
                    listToModify.wrappedValue.insert(taskToMove, at: adjustedTargetIndex)
                }

            }
            // CASE 2: Moving to a different column
            else {
                // Remove from the source list
                if let index = todoTasks.firstIndex(where: { $0.id == droppedTask.id }) {
                    _ = todoTasks.remove(at: index)
                } else if let index = doneTasks.firstIndex(where: { $0.id == droppedTask.id }) {
                    _ = doneTasks.remove(at: index)
                }

                // Add to the target list at the specified index
                var taskToMove = droppedTask
                taskToMove.status = targetStatus
                if targetStatus == .todo {
                    todoTasks.insert(taskToMove, at: targetIndex)
                } else {
                    doneTasks.insert(taskToMove, at: targetIndex)
                }
            }
            self.draggedTaskID = nil // Clear the dragged task ID after the move
        }
    }
}
