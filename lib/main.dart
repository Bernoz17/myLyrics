import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:home_widget/home_widget.dart';
import 'database_helper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Platform.isWindows || Platform.isLinux) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
  
  if (Platform.isIOS || Platform.isAndroid) {
    try {
      await HomeWidget.setAppGroupId('group.it.bernoz.myLyrics');
    } catch (e) {
      print("Errore HomeWidget in avvio: $e");
    }
  }

  await DatabaseHelper.instance.popolaDatabaseIniziale();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Le Mie Barre',
      theme: ThemeData.dark(useMaterial3: true).copyWith(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.tealAccent,
          brightness: Brightness.dark,
        ),
      ),
      home: const MainNavigationScreen(),
    );
  }
}

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 1; // 1 è la Home

  // Aggiunta la schermata dei Preferiti all'indice 2
  final List<Widget> _pages = [
    const AllPhrasesTab(),
    const HomeTab(),
    const FavoritesTab(),
    const ArtistsTab(),
    const WidgetSettingsTab(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.list_alt), label: 'Tutte'),
          NavigationDestination(icon: Icon(Icons.home), label: 'Oggi'),
          NavigationDestination(icon: Icon(Icons.star), label: 'Preferiti'),
          NavigationDestination(icon: Icon(Icons.mic), label: 'Artisti'),
          NavigationDestination(icon: Icon(Icons.widgets), label: 'Widget'),
        ],
      ),
    );
  }
}

// ----------------------------------------------------------------------
// SCHERMATA: Frase del giorno
// ----------------------------------------------------------------------
class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  Map<String, dynamic>? fraseDelGiorno;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _caricaFraseRandom();
  }

  Future<void> _caricaFraseRandom() async {
    setState(() => isLoading = true);
    final frase = await DatabaseHelper.instance.getRandomFrase();
    
    setState(() {
      fraseDelGiorno = frase;
      isLoading = false;
    });

    if (frase != null) {
      // Eseguiamo l'aggiornamento del widget SOLO su iOS e Android
      if (Platform.isIOS || Platform.isAndroid) {
        try {
          await HomeWidget.saveWidgetData<String>('widget_testo', frase['testo']);
          await HomeWidget.saveWidgetData<String>('widget_dettagli', "${frase['titolo']} - ${frase['artista']}");
          await HomeWidget.updateWidget(iOSName: 'FrasiWidget'); 
        } catch (e) {
          print("Nessun widget trovato o errore di aggiornamento: $e");
        }
      } else {
        print("Test su PC: Widget saltato. Frase caricata: ${frase['testo']}");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Frase del Giorno"), centerTitle: true),
      body: Center(
        child: isLoading
            ? const CircularProgressIndicator()
            : fraseDelGiorno == null
                ? const Text("Nessuna frase trovata")
                : Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.format_quote, size: 60, color: Colors.tealAccent),
                        const SizedBox(height: 20),
                        Text(
                          '"${fraseDelGiorno!['testo']}"',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, fontStyle: FontStyle.italic),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          "${fraseDelGiorno!['titolo']} - ${fraseDelGiorno!['artista']}",
                          style: TextStyle(fontSize: 16, color: Colors.grey.shade400),
                        ),
                        const SizedBox(height: 50),
                        ElevatedButton.icon(
                          onPressed: _caricaFraseRandom,
                          icon: const Icon(Icons.shuffle),
                          label: const Text("Nuova Frase"),
                        )
                      ],
                    ),
                  ),
      ),
    );
  }
}

// ----------------------------------------------------------------------
// WIDGET CONDIVISO: La singola Card con i pulsanti integrati
// ----------------------------------------------------------------------
// L'ho estratto così non devi ripetere 100 righe di codice per ogni schermata!
class FraseCardWidget extends StatelessWidget {
  final Map<String, dynamic> frase;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggleFavorite;

  const FraseCardWidget({
    super.key,
    required this.frase,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleFavorite,
  });

  @override
  Widget build(BuildContext context) {
    final bool isPreferito = frase['preferito'] == 1;

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      child: ListTile(
        title: Text(frase['testo'], style: const TextStyle(fontWeight: FontWeight.w500)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Text("${frase['titolo']} - ${frase['artista']}"),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icona Preferiti
            IconButton(
              icon: Icon(
                isPreferito ? Icons.star : Icons.star_border,
                color: isPreferito ? Colors.amber : Colors.grey,
              ),
              onPressed: onToggleFavorite,
            ),
            // Icona Modifica
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.grey),
              onPressed: onEdit,
            ),
            // Icona Elimina
            IconButton(
              icon: Icon(Icons.delete, color: Colors.red.shade400),
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}

// ----------------------------------------------------------------------
// FUNZIONI CONDIVISE (MIXIN)
// ----------------------------------------------------------------------
mixin InterazioniFrase<T extends StatefulWidget> on State<T> {
  void mostraDialogoFrase({Map<String, dynamic>? fraseEsistente}) {
    final testoCtrl = TextEditingController(text: fraseEsistente?['testo']);
    final titoloCtrl = TextEditingController(text: fraseEsistente?['titolo']);
    final artistaCtrl = TextEditingController(text: fraseEsistente?['artista']);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(fraseEsistente == null ? "Aggiungi nuova frase" : "Modifica frase"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: testoCtrl,
                decoration: const InputDecoration(labelText: "Testo della frase", border: OutlineInputBorder()),
                maxLines: 3,
              ),
              const SizedBox(height: 10),
              TextField(
                controller: titoloCtrl,
                decoration: const InputDecoration(labelText: "Titolo canzone", border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: artistaCtrl,
                decoration: const InputDecoration(labelText: "Artista (separati da virgola)", border: OutlineInputBorder()),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Annulla"),
          ),
          ElevatedButton(
            onPressed: () async {
              final Map<String, dynamic> dati = {
                'testo': testoCtrl.text,
                'titolo': titoloCtrl.text,
                'artista': artistaCtrl.text,
              };

              if (fraseEsistente == null) {
                await DatabaseHelper.instance.insertFrase(dati);
              } else {
                dati['id'] = fraseEsistente['id'];
                await DatabaseHelper.instance.updateFrase(dati);
              }

              if (mounted) {
                Navigator.pop(context);
                aggiornaSchermata(); 
              }
            },
            child: const Text("Salva"),
          )
        ],
      ),
    );
  }

  void confermaEliminazione(Map<String, dynamic> frase) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Elimina frase"),
        content: const Text("Sei sicuro di voler eliminare questa frase?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Annulla")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade800),
            onPressed: () async {
              await DatabaseHelper.instance.deleteFrase(frase['id']);
              if (mounted) {
                Navigator.pop(context);
                aggiornaSchermata(); 
              }
            },
            child: const Text("Elimina", style: TextStyle(color: Colors.white)),
          )
        ],
      ),
    );
  }

  Future<void> toggleStar(Map<String, dynamic> frase) async {
    int nuovoStato = (frase['preferito'] == 1) ? 0 : 1;
    await DatabaseHelper.instance.togglePreferito(frase['id'], nuovoStato);
    aggiornaSchermata();
  }

  // Funzione esportazione TUTTO
  Future<void> esportaTuttoJSON() async {
    final frasi = await DatabaseHelper.instance.getTutteLeFrasi(ascending: true, query: '');
    final frasiPulite = frasi.map((f) => {
      'testo': f['testo'], 'titolo': f['titolo'], 'artista': f['artista'], 'preferito': f['preferito']
    }).toList();
    const encoder = JsonEncoder.withIndent('  ');
    await Clipboard.setData(ClipboardData(text: encoder.convert(frasiPulite)));
    if (mounted) _mostraNotifica("Tutto il JSON è stato copiato negli appunti! 📋");
  }

  // NUOVA: Funzione esportazione SOLO PREFERITI
  Future<void> esportaPreferitiJSON() async {
    final frasi = await DatabaseHelper.instance.getFrasiPreferite();
    final frasiPulite = frasi.map((f) => {
      'testo': f['testo'], 'titolo': f['titolo'], 'artista': f['artista'], 'preferito': f['preferito']
    }).toList();
    const encoder = JsonEncoder.withIndent('  ');
    await Clipboard.setData(ClipboardData(text: encoder.convert(frasiPulite)));
    if (mounted) _mostraNotifica("${frasi.length} frasi preferite copiate negli appunti! 🌟");
  }

  void _mostraNotifica(String testo) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(testo), backgroundColor: Colors.teal, duration: const Duration(seconds: 4)),
    );
  }

  void aggiornaSchermata(); 
}

// ----------------------------------------------------------------------
// SCHERMATA: Tutte le frasi
// ----------------------------------------------------------------------
class AllPhrasesTab extends StatefulWidget {
  const AllPhrasesTab({super.key});

  @override
  State<AllPhrasesTab> createState() => _AllPhrasesTabState();
}

class _AllPhrasesTabState extends State<AllPhrasesTab> with InterazioniFrase {
  bool isAscending = true;
  String searchQuery = ''; 

  @override
  void aggiornaSchermata() => setState(() {});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Tutte le frasi"),
        actions: [
          IconButton(icon: const Icon(Icons.copy_all), tooltip: 'Esporta Tutto', onPressed: esportaTuttoJSON),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => mostraDialogoFrase(), 
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 12.0, right: 12.0, top: 12.0, bottom: 4.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Cerca parola, artista o brano...',
                prefixIcon: const Icon(Icons.search, color: Colors.tealAccent),
                filled: true,
                fillColor: Colors.black26,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
              onChanged: (value) => setState(() => searchQuery = value),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(right: 12.0, bottom: 4.0),
              child: TextButton.icon(
                onPressed: () => setState(() => isAscending = !isAscending),
                icon: Icon(isAscending ? Icons.arrow_downward : Icons.arrow_upward, color: Colors.tealAccent, size: 20),
                label: Text(isAscending ? "Ordina: A - Z" : "Ordina: Z - A", style: const TextStyle(color: Colors.tealAccent, fontWeight: FontWeight.bold)),
              ),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: DatabaseHelper.instance.getTutteLeFrasi(ascending: isAscending, query: searchQuery),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final frasi = snapshot.data!;
                if (frasi.isEmpty) return const Center(child: Text("Nessun risultato trovato."));

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  itemCount: frasi.length,
                  itemBuilder: (context, index) {
                    final frase = frasi[index];
                    return FraseCardWidget(
                      frase: frase,
                      onEdit: () => mostraDialogoFrase(fraseEsistente: frase),
                      onDelete: () => confermaEliminazione(frase),
                      onToggleFavorite: () => toggleStar(frase),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ----------------------------------------------------------------------
// SCHERMATA: Preferiti (Aggiornata con Export e Contatore)
// ----------------------------------------------------------------------
class FavoritesTab extends StatefulWidget {
  const FavoritesTab({super.key});

  @override
  State<FavoritesTab> createState() => _FavoritesTabState();
}

class _FavoritesTabState extends State<FavoritesTab> with InterazioniFrase {
  @override
  void aggiornaSchermata() => setState(() {});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("I Tuoi Preferiti"),
        actions: [
          // Questo pulsante richiama solo l'esportazione dei preferiti
          IconButton(
            icon: const Icon(Icons.file_download), 
            tooltip: 'Esporta Solo Preferiti', 
            onPressed: esportaPreferitiJSON
          ),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: DatabaseHelper.instance.getFrasiPreferite(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final frasi = snapshot.data!;
          
          if (frasi.isEmpty) {
            return const Center(child: Text("Ancora nessuna frase preferita.\nClicca sulla stella per aggiungerla!", textAlign: TextAlign.center));
          }

          return Column(
            children: [
              // Contatore delle frasi preferite
              Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                width: double.infinity,
                color: Colors.black26,
                child: Text(
                  "Hai salvato ${frasi.length} ${frasi.length == 1 ? 'frase' : 'frasi'}",
                  style: const TextStyle(fontStyle: FontStyle.italic, color: Colors.amber),
                  textAlign: TextAlign.center,
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  itemCount: frasi.length,
                  itemBuilder: (context, index) {
                    final frase = frasi[index];
                    return FraseCardWidget(
                      frase: frase,
                      onEdit: () => mostraDialogoFrase(fraseEsistente: frase),
                      onDelete: () => confermaEliminazione(frase),
                      onToggleFavorite: () => toggleStar(frase),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ----------------------------------------------------------------------
// SCHERMATA: Divisione per Artista
// ----------------------------------------------------------------------
class ArtistsTab extends StatefulWidget {
  const ArtistsTab({super.key});

  @override
  State<ArtistsTab> createState() => _ArtistsTabState();
}

class _ArtistsTabState extends State<ArtistsTab> with InterazioniFrase {
  @override
  void aggiornaSchermata() => setState(() {});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Artisti")),
      body: FutureBuilder<List<String>>(
        future: DatabaseHelper.instance.getArtisti(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final artisti = snapshot.data!;
          
          return ListView.builder(
            itemCount: artisti.length,
            itemBuilder: (context, index) {
              final artista = artisti[index];
              return ExpansionTile(
                leading: const CircleAvatar(child: Icon(Icons.person)),
                title: Text(artista, style: const TextStyle(fontWeight: FontWeight.bold)),
                children: [
                  FutureBuilder<List<Map<String, dynamic>>>(
                    future: DatabaseHelper.instance.getFrasiByArtista(artista),
                    builder: (context, snapshotFrasi) {
                      if (!snapshotFrasi.hasData) {
                        return const Padding(padding: EdgeInsets.all(16.0), child: CircularProgressIndicator());
                      }
                      
                      final frasiArtista = snapshotFrasi.data!;
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 8.0),
                        child: Column(
                          children: frasiArtista.map((f) => FraseCardWidget(
                            frase: f,
                            onEdit: () => mostraDialogoFrase(fraseEsistente: f),
                            onDelete: () => confermaEliminazione(f),
                            onToggleFavorite: () => toggleStar(f),
                          )).toList(),
                        ),
                      );
                    },
                  )
                ],
              );
            },
          );
        },
      ),
    );
  }
}
// ----------------------------------------------------------------------
// SCHERMATA: Impostazioni Stile Widget
// ----------------------------------------------------------------------
class WidgetSettingsTab extends StatefulWidget {
  const WidgetSettingsTab({super.key});

  @override
  State<WidgetSettingsTab> createState() => _WidgetSettingsTabState();
}

class _WidgetSettingsTabState extends State<WidgetSettingsTab> {
  String bgColor = "000000";
  String textColor = "FFFFFF";
  String fontStyle = "default";

  @override
  void initState() {
    super.initState();
    _caricaImpostazioni();
  }

  // Legge le impostazioni salvate nella memoria dell'iPhone
  Future<void> _caricaImpostazioni() async {
    if (Platform.isIOS || Platform.isAndroid) {
      final savedBg = await HomeWidget.getWidgetData<String>('widget_bgColor');
      final savedText = await HomeWidget.getWidgetData<String>('widget_textColor');
      final savedFont = await HomeWidget.getWidgetData<String>('widget_fontStyle');
      
      setState(() {
        if (savedBg != null) bgColor = savedBg;
        if (savedText != null) textColor = savedText;
        if (savedFont != null) fontStyle = savedFont;
      });
    }
  }

  // Salva e forza l'aggiornamento grafico del widget su iOS
  Future<void> _salvaEApplica() async {
    if (Platform.isIOS || Platform.isAndroid) {
      await HomeWidget.saveWidgetData<String>('widget_bgColor', bgColor);
      await HomeWidget.saveWidgetData<String>('widget_textColor', textColor);
      await HomeWidget.saveWidgetData<String>('widget_fontStyle', fontStyle);
      await HomeWidget.updateWidget(iOSName: 'FrasiWidget');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Stile del widget aggiornato! ✨"), backgroundColor: Colors.teal),
        );
      }
    } else {
      print("Test su PC: Salvataggio simulato. Bg: $bgColor, Testo: $textColor, Font: $fontStyle");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Personalizza Widget")),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text("Sfondo del Widget", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: bgColor,
            decoration: const InputDecoration(border: OutlineInputBorder()),
            items: const [
              DropdownMenuItem(value: "000000", child: Text("Nero Assoluto")),
              DropdownMenuItem(value: "transparent", child: Text("Trasparente (Invisibile)")),
              DropdownMenuItem(value: "1C1C1E", child: Text("Grigio Scuro")),
              DropdownMenuItem(value: "FFFFFF", child: Text("Bianco")),
              DropdownMenuItem(value: "00C49A", child: Text("Verde Acqua")),
            ],
            onChanged: (val) => setState(() => bgColor = val!),
          ),
          
          const SizedBox(height: 24),
          const Text("Colore del Testo", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: textColor,
            decoration: const InputDecoration(border: OutlineInputBorder()),
            items: const [
              DropdownMenuItem(value: "FFFFFF", child: Text("Bianco")),
              DropdownMenuItem(value: "000000", child: Text("Nero")),
              DropdownMenuItem(value: "1DE9B6", child: Text("Verde Acqua Acceso")),
              DropdownMenuItem(value: "FFD600", child: Text("Giallo Oro")),
            ],
            onChanged: (val) => setState(() => textColor = val!),
          ),

          const SizedBox(height: 24),
          const Text("Stile del Font", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: fontStyle,
            decoration: const InputDecoration(border: OutlineInputBorder()),
            items: const [
              DropdownMenuItem(value: "default", child: Text("Standard iOS")),
              DropdownMenuItem(value: "serif", child: Text("Elegante (Serif)")),
              DropdownMenuItem(value: "monospaced", child: Text("Macchina da Scrivere")),
              DropdownMenuItem(value: "rounded", child: Text("Moderno Arrotondato")),
            ],
            onChanged: (val) => setState(() => fontStyle = val!),
          ),

          const SizedBox(height: 40),
          ElevatedButton.icon(
            onPressed: _salvaEApplica,
            icon: const Icon(Icons.check),
            label: const Padding(
              padding: EdgeInsets.symmetric(vertical: 16.0),
              child: Text("Applica e Aggiorna Widget", style: TextStyle(fontSize: 16)),
            ),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.black),
          )
        ],
      ),
    );
  }
}