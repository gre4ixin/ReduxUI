//
//  ContentView.swift
//  ReduxUIExampleApp
//
//  Created by p.grechikhin on 15.12.2021.
//

import SwiftUI
import ReduxUI

struct ContentView: View {
    
    @EnvironmentObject var store: Store<AppState, AppAction, RouteWrapperAction>
    
    var body: some View {
        VStack {
            ScrollView {
                ForEach(store.state.users) { user in
                    HStack {
                        VStack {
                            Text(user.name)
                                .padding(.leading, 16)
                            Text(user.phone)
                                .padding(.leading, 16)
                        }
                        Spacer()
                    }
                    Divider()
                }
            }
            Spacer()
            if store.state.isLoading {
                Text("Loading")
            }
            
            if !store.state.errorMessage.isEmpty {
                Text(LocalizedStringKey(store.state.errorMessage))
            }
            
            Button {
                store.dispatch(.fetch)
            } label: {
                Text("fetch users")
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
