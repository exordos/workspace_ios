//
//  ProjectsView.swift
//  WorkspaceBeta
//
//  
//

import SwiftUI
import Combine

struct ProjectsView: View {

    @ObservedObject var viewModel: ProjectsViewModel

    var body: some View {
        VStack(alignment: .center) {
            Text("Выберите проект")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(Color.textHeaders)
                .padding(.bottom, 10.0)
            Text("Сообщения и настройки каждого проекта изолированы")
                .font(.system(size: 14))
                .foregroundColor(Color.textAdditional50)
                .padding(.bottom, 44.0)
                .padding(.horizontal, 20.0)
                .multilineTextAlignment(.center)
            if viewModel.loadingState == .loading {
                FullScreenLoaderView()
            } else if viewModel.model.projects.isEmpty {
                VStack {
                    Text("Проектов нет,\nобратитесь к администратору")
                        .foregroundStyle(Color.textHeaders)
                        .font(.system(size: 14))
                        .multilineTextAlignment(.center)
                        .onAppear {
                            viewModel.onAppear()
                        }
                }
            } else {
                ScrollView {
                    VStack(alignment: .leading) {
                        ForEach(viewModel.model.projects, id: \.self) { project in
                            HStack {
                                VStack(alignment: .leading, spacing: 4.0) {
                                    Text(project.name)
                                        .foregroundStyle(Color.textHeaders)
                                        .font(.system(size: 14))
                                        .lineLimit(1)
                                        .truncationMode(.tail)
                                    Text("ID: \(project.uuid)")
                                        .foregroundStyle(Color.textAdditional30)
                                        .font(.system(size: 12))
                                        .lineLimit(1)
                                        .truncationMode(.tail)
                                }
                                Spacer()
                            }
                            .frame(maxWidth: .infinity)
                            .padding(12.0)
                            .background(Color.searchBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 8.0))
                            .padding(12.0)
                            .onTapGesture {
                                viewModel.onTap(on: project)
                            }
                        }
                    }
                }
                .showLoader(viewModel.selectProjectLoadingState == .loading)
            }
        }
    }
}
