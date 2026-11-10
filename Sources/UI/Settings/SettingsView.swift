import SwiftUI

public struct SettingsView: View {
    @ObservedObject private var sessionManager = SessionManager.shared
    @ObservedObject private var regramService = RegramService.shared
    @State private var showLoginSheet = false
    @State private var showLogoutConfirm = false
    @State private var toast: ToastMessage?

    public init() {}

    public var body: some View {
        NavigationStack {
            List {
                // Sezione Account Instagram
                Section(header: Text("Account Instagram")) {
                    if sessionManager.isLoggedIn {
                        HStack(spacing: 12) {
                            Image(systemName: "person.crop.circle.badge.checkmark")
                                .font(.title2)
                                .foregroundColor(.green)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(sessionManager.currentUsername ?? "Utente Instagram")
                                    .font(.headline)
                                Text("Sessione Web attiva")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            Button("Esci", role: .destructive) {
                                showLogoutConfirm = true
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                        .padding(.vertical, 4)
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Nessun account collegato")
                                .font(.headline)
                            Text("Accedi con il tuo account Instagram per cercare qualsiasi utente e visualizzare i post in alta risoluzione.")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            Button(action: { showLoginSheet = true }) {
                                HStack {
                                    Image(systemName: "key.fill")
                                    Text("Accedi con Instagram")
                                        .fontWeight(.semibold)
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 8))
                            }
                            .padding(.top, 4)
                        }
                        .padding(.vertical, 4)
                    }
                }

                // Sezione Regram & Watermark
                Section(header: Text("Opzioni Regram"), footer: Text("Il badge indica l'autore originale del post ricondiviso in modo elegante e trasparente.")) {
                    Picker("Posizione badge predefinita", selection: $regramService.defaultWatermarkPosition) {
                        ForEach(WatermarkPosition.allCases) { pos in
                            Text(pos.rawValue).tag(pos)
                        }
                    }

                    Toggle("Includi didascalia originale", isOn: $regramService.includeCaptionInRegram)
                    Toggle("Salva sempre in Foto prima di condividere", isOn: $regramService.autoSaveOnRegram)
                }

                // Sezione Filosofia No-Doomscrolling
                Section(header: Text("Filosofia No-Doomscrolling")) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: "sparkles")
                                .foregroundColor(.accentColor)
                            Text("Zero Reel, Zero Feed, Solo Ricerca")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        }

                        Text("Lente 2 è progettata per eliminare la dipendenza algoritmica. Non ci sono feed infiniti, raccomandazioni sponsorizzate o caroselli di reel creati per catturare la tua attenzione. Usi l'app solo quando vuoi cercare qualcuno in modo deliberato, guardare i suoi post e salvare o ricondividere i contenuti.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }

                // Sezione Cache & Memoria
                Section(header: Text("Archiviazione")) {
                    Button(action: clearCache) {
                        HStack {
                            Text("Svuota cache immagini temporanea")
                            Spacer()
                            Image(systemName: "trash")
                                .foregroundColor(.secondary)
                        }
                    }
                }

                // Info App
                Section(header: Text("Info")) {
                    HStack {
                        Text("Versione")
                        Spacer()
                        Text("2.0.0 (Build 1)")
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Sviluppato da")
                        Spacer()
                        Text("Davoxic")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Impostazioni")
            .sheet(isPresented: $showLoginSheet) {
                InstagramLoginView()
            }
            .confirmationDialog("Sei sicuro di voler uscire da Instagram?", isPresented: $showLogoutConfirm, titleVisibility: .visible) {
                Button("Esci", role: .destructive) {
                    sessionManager.logout()
                    toast = ToastMessage(title: "Disconnesso con successo", systemImage: "checkmark.circle")
                }
                Button("Annulla", role: .cancel) {}
            }
            .overlay(alignment: .top) {
                if let toast = toast {
                    ToastView(message: toast)
                        .padding(.top, 12)
                }
            }
        }
    }

    private func clearCache() {
        URLCache.shared.removeAllCachedResponses()
        toast = ToastMessage(title: "Cache svuotata!", systemImage: "trash.circle.fill")
    }
}
