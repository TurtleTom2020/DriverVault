
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

const bg=Color(0xff07060b), card=Color(0xff10101a), card2=Color(0xff171724);
const purple=Color(0xffb115ff), gold=Color(0xffffc438);
const themePresets=<String,Color>{
 'Purple + Gold':Color(0xffb115ff),'Blue':Color(0xff168cff),'Red':Color(0xffff3d5a),'Green':Color(0xff25c96f),'Copper / Orange':Color(0xffd97832)
};

void main()=>runApp(const DriverVault());
class DriverVault extends StatefulWidget{const DriverVault({super.key});@override State<DriverVault> createState()=>_DriverVaultState();}
class _DriverVaultState extends State<DriverVault>{
 String themeName='Purple + Gold',finish='Metallic';
 @override void initState(){super.initState();_load();}
 Future<void> _load()async{final p=await SharedPreferences.getInstance();if(mounted)setState((){themeName=p.getString('theme_name')??'Purple + Gold';finish=p.getString('theme_finish')??'Metallic';});}
 Future<void> _theme()async{String draft=themeName,draftFinish=finish;await showModalBottomSheet(context:context,isScrollControlled:true,backgroundColor:const Color(0xff111019),builder:(bc)=>StatefulBuilder(builder:(bc,setB)=>SafeArea(child:Padding(padding:const EdgeInsets.all(20),child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[
  const Text('DriverVault Theme',style:TextStyle(fontSize:22,fontWeight:FontWeight.w900)),const SizedBox(height:14),
  const Label('ACCENT'),const SizedBox(height:8),Wrap(spacing:8,runSpacing:8,children:themePresets.entries.map((e)=>ChoiceChip(avatar:CircleAvatar(backgroundColor:e.value),label:Text(e.key),selected:draft==e.key,onSelected:(_)=>setB(()=>draft=e.key))).toList()),
  const SizedBox(height:16),const Label('FINISH'),const SizedBox(height:8),Wrap(spacing:8,children:['Solid','Matte','Metallic','Pearlescent','Two-tone'].map((x)=>ChoiceChip(label:Text(x),selected:draftFinish==x,onSelected:(_)=>setB(()=>draftFinish=x))).toList()),
  const SizedBox(height:18),Container(height:72,width:double.infinity,decoration:BoxDecoration(borderRadius:BorderRadius.circular(14),gradient:LinearGradient(colors:[themePresets[draft]!,draftFinish=='Two-tone'?gold:themePresets[draft]!.withValues(alpha:.35)]),border:Border.all(color:gold.withValues(alpha:.7))),child:Center(child:Text('$draft • $draftFinish',style:const TextStyle(fontWeight:FontWeight.w900)))),
  const SizedBox(height:16),SizedBox(width:double.infinity,child:FilledButton(onPressed:()async{themeName=draft;finish=draftFinish;final p=await SharedPreferences.getInstance();await p.setString('theme_name',themeName);await p.setString('theme_finish',finish);if(mounted)setState((){});if(bc.mounted)Navigator.pop(bc);},child:const Text('Apply Theme')))
 ])))));if(mounted)setState((){});}
 @override Widget build(BuildContext c){final accent=themePresets[themeName]??purple;return MaterialApp(debugShowCheckedModeBanner:false,title:'DriverVault',theme:ThemeData.dark(useMaterial3:true).copyWith(scaffoldBackgroundColor:bg,colorScheme:ColorScheme.fromSeed(seedColor:accent,brightness:Brightness.dark),appBarTheme:const AppBarTheme(backgroundColor:bg,surfaceTintColor:Colors.transparent)),home:Shell(onTheme:_theme));}
}


class Shell extends StatefulWidget{final VoidCallback onTheme;const Shell({super.key,required this.onTheme});@override State<Shell> createState()=>_Shell();}
class _Shell extends State<Shell>{
 int tab=0; List<dynamic> games=[]; List<dynamic> setups=[]; Set<String> favourites={};
 @override void initState(){super.initState();load();}
 Future<void> load()async{
  final data=jsonDecode(await rootBundle.loadString('assets/catalog/catalog.json'));
  final p=await SharedPreferences.getInstance();
  games=data['games']; setups=jsonDecode(p.getString('setups')??'[]'); favourites=(p.getStringList('favourites')??[]).toSet();
  if(mounted)setState((){});
 }
 Future<void> persist()async{final p=await SharedPreferences.getInstance();await p.setString('setups',jsonEncode(setups));}
 Future<void> toggleFavourite(String id)async{setState(()=>favourites.contains(id)?favourites.remove(id):favourites.add(id));final p=await SharedPreferences.getInstance();await p.setStringList('favourites',favourites.toList());}
 void add(Map<String,dynamic> s){final i=setups.indexWhere((x)=>x['id']==s['id']);if(i>=0){setups[i]=s;}else{setups.add(s);}persist();setState((){});}
 @override Widget build(BuildContext c)=>Scaffold(
  body:SafeArea(child:IndexedStack(index:tab,children:[
   Home(games:games,setups:setups,onCatalogue:()=>setState(()=>tab=1),onSetups:()=>setState(()=>tab=2),onTheme:widget.onTheme),
   Catalogue(games:games,onSave:add,favourites:favourites,onFavourite:toggleFavourite),
   MySetups(items:setups,games:games,onSave:add,onDelete:(x){setups.remove(x);persist();setState((){});}),
   const Hardware(),
  ])),
  bottomNavigationBar:NavigationBar(height:72,backgroundColor:const Color(0xff0b0910),indicatorColor:const Color(0xff65209a),
   selectedIndex:tab,onDestinationSelected:(v)=>setState(()=>tab=v),destinations:const[
    NavigationDestination(icon:Icon(Icons.home_rounded),label:'Home'),
    NavigationDestination(icon:Icon(Icons.directions_car_filled_rounded),label:'Catalogue'),
    NavigationDestination(icon:Icon(Icons.tune_rounded),label:'My Setups'),
    NavigationDestination(icon:Icon(Icons.sports_esports_rounded),label:'Hardware')]));
}

class Home extends StatelessWidget{
 final List games,setups; final VoidCallback onCatalogue,onSetups,onTheme;
 const Home({super.key,required this.games,required this.setups,required this.onCatalogue,required this.onSetups,required this.onTheme});
 @override Widget build(BuildContext c)=>ListView(padding:const EdgeInsets.fromLTRB(18,12,18,28),children:[
  Row(children:[
   Image.asset('assets/branding/drivervault_icon.png',width:82,height:82),
   const SizedBox(width:10),
   const Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    Text.rich(TextSpan(children:[TextSpan(text:'Driver',style:TextStyle(color:Colors.white)),TextSpan(text:'Vault',style:TextStyle(color:gold))]),
     style:TextStyle(fontSize:30,fontWeight:FontWeight.w900,letterSpacing:-1)),
    Text('YOUR GAMES • YOUR SETUPS • ONE VAULT',style:TextStyle(fontSize:8.5,color:Colors.white60,letterSpacing:.8))])),
   IconButton.filledTonal(onPressed:onTheme,icon:const Icon(Icons.settings_rounded))]),
  const SizedBox(height:22),
  Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[const Label('YOUR GAMES'),TextButton(onPressed:onCatalogue,child:const Text('VIEW ALL ›'))]),
  if(games.isNotEmpty) HeroGame(game:games[0],onTap:onCatalogue),
  const SizedBox(height:9),
  if(games.length>2) Row(children:[Expanded(child:GameTile(game:games[1],onTap:onCatalogue)),const SizedBox(width:9),Expanded(child:GameTile(game:games[2],onTap:onCatalogue))]),
  const SizedBox(height:9),
  if(games.length>4) Row(children:[Expanded(child:GameTile(game:games[3],onTap:onCatalogue)),const SizedBox(width:9),Expanded(child:GameTile(game:games[4],onTap:onCatalogue))]),
  const SizedBox(height:9),
  if(games.length>6) Row(children:[Expanded(child:GameTile(game:games[5],onTap:onCatalogue)),const SizedBox(width:9),Expanded(child:GameTile(game:games[6],onTap:onCatalogue))]),
  const SizedBox(height:18),const Label('QUICK ACCESS'),const SizedBox(height:10),
  Row(children:[
   Expanded(child:Quick(icon:Icons.directions_car_filled_rounded,title:'Catalogue',sub:'Find vehicles',tap:onCatalogue)),
   const SizedBox(width:8),Expanded(child:Quick(icon:Icons.tune_rounded,title:'My Setups',sub:'View & manage',tap:onSetups)),
   const SizedBox(width:8),const Expanded(child:Quick(icon:Icons.sports_esports_rounded,title:'Hardware',sub:'Manage profiles')),
   const SizedBox(width:8),const Expanded(child:Quick(icon:Icons.star_rounded,title:'Favourites',sub:'Your saved cars'))]),
 ]);
}
class GameArt extends StatelessWidget {
  final dynamic game;
  final BoxFit fit;
  const GameArt({super.key, required this.game, this.fit = BoxFit.cover});

  @override
  Widget build(BuildContext context) {
    final remote = game['remote_art']?.toString() ?? '';
    final local = game['art']?.toString() ?? '';
    if (remote.isNotEmpty) {
      return Image.network(
        remote,
        fit: fit,
        filterQuality: FilterQuality.high,
        errorBuilder: (_, __, ___) => Image.asset(
          local,
          fit: fit,
          filterQuality: FilterQuality.high,
        ),
      );
    }
    return Image.asset(local, fit: fit, filterQuality: FilterQuality.high);
  }
}

class Label extends StatelessWidget{final String s;const Label(this.s,{super.key});@override Widget build(BuildContext c)=>Text(s,style:const TextStyle(color:purple,fontSize:13,fontWeight:FontWeight.w900,letterSpacing:1.5));}
class HeroGame extends StatelessWidget{final dynamic game;final VoidCallback onTap;const HeroGame({super.key,required this.game,required this.onTap});
 @override Widget build(BuildContext c)=>InkWell(onTap:onTap,borderRadius:BorderRadius.circular(18),child:Container(height:188,decoration:BoxDecoration(borderRadius:BorderRadius.circular(18),border:Border.all(color:gold.withValues(alpha:.55))),child:ClipRRect(borderRadius:BorderRadius.circular(17),child:GameArt(game:game))));}
class GameTile extends StatelessWidget{final dynamic game;final VoidCallback onTap;const GameTile({super.key,required this.game,required this.onTap});
 @override Widget build(BuildContext c)=>InkWell(onTap:onTap,borderRadius:BorderRadius.circular(15),child:AspectRatio(aspectRatio:1.28,child:ClipRRect(borderRadius:BorderRadius.circular(15),child:GameArt(game:game))));}
class Quick extends StatelessWidget{final IconData icon;final String title,sub;final VoidCallback? tap;const Quick({super.key,required this.icon,required this.title,required this.sub,this.tap});
 @override Widget build(BuildContext c)=>InkWell(onTap:tap,borderRadius:BorderRadius.circular(12),child:Container(height:88,padding:const EdgeInsets.all(10),decoration:BoxDecoration(color:card,borderRadius:BorderRadius.circular(12),border:Border.all(color:Colors.white10)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Icon(icon,color:purple,size:25),const Spacer(),Text(title,maxLines:1,style:const TextStyle(fontWeight:FontWeight.w800,fontSize:12)),Text(sub,maxLines:1,style:const TextStyle(fontSize:9,color:Colors.white54))])));}
class Catalogue extends StatefulWidget{final List games;final ValueChanged<Map<String,dynamic>> onSave;final Set<String> favourites;final ValueChanged<String> onFavourite;const Catalogue({super.key,required this.games,required this.onSave,required this.favourites,required this.onFavourite});@override State<Catalogue> createState()=>_Catalogue();}
class _Catalogue extends State<Catalogue>{
 String q='';
 @override Widget build(BuildContext c){final filtered=widget.games.where((g)=>g['name'].toString().toLowerCase().contains(q.toLowerCase())).toList();
 return ListView(padding:const EdgeInsets.fromLTRB(18,15,18,28),children:[
  const Text('Catalogue',style:TextStyle(fontSize:28,fontWeight:FontWeight.w900)),const Text('Select a game to browse vehicles.',style:TextStyle(color:Colors.white60,fontSize:12)),const SizedBox(height:14),
  TextField(onChanged:(v)=>setState(()=>q=v),decoration:InputDecoration(prefixIcon:const Icon(Icons.search),hintText:'Search games...',filled:true,fillColor:card,border:OutlineInputBorder(borderRadius:BorderRadius.circular(10),borderSide:BorderSide.none))),
  const SizedBox(height:12),
  ...filtered.map((g)=>GameRow(game:g,onTap:()=>Navigator.push(c,MaterialPageRoute(builder:(_)=>VehicleCatalogue(game:g,onSave:widget.onSave,favourites:widget.favourites,onFavourite:widget.onFavourite))))),
 ]);}
}
class GameRow extends StatelessWidget{final dynamic game;final VoidCallback onTap;const GameRow({super.key,required this.game,required this.onTap});
 @override Widget build(BuildContext c){final n=(game['vehicles'] as List).length;final official=game['official_total'];return InkWell(onTap:onTap,child:Container(height:76,margin:const EdgeInsets.only(bottom:2),padding:const EdgeInsets.all(8),decoration:const BoxDecoration(border:Border(bottom:BorderSide(color:Colors.white12))),child:Row(children:[
  SizedBox(width:86,child:ClipRRect(borderRadius:BorderRadius.circular(7),child:GameArt(game:game))),const SizedBox(width:12),
  Expanded(child:Column(mainAxisAlignment:MainAxisAlignment.center,crossAxisAlignment:CrossAxisAlignment.start,children:[Text(game['name'],style:const TextStyle(fontWeight:FontWeight.w800)),Text(official!=null&&n<official?'$n of $official loaded':'$n vehicles',style:const TextStyle(color:Colors.white60,fontSize:11))])),const Icon(Icons.chevron_right)])));}
}
class VehicleCatalogue extends StatefulWidget {
  final dynamic game;
  final ValueChanged<Map<String,dynamic>> onSave; final Set<String> favourites; final ValueChanged<String> onFavourite;
  const VehicleCatalogue({super.key, required this.game, required this.onSave,required this.favourites,required this.onFavourite});
  @override State<VehicleCatalogue> createState() => _VehicleCatalogue();
}

class _VehicleCatalogue extends State<VehicleCatalogue> {
  String q = '';
  String make = 'All Makes';
  String vehicleClass = 'All Classes';
  bool grid = true;

  List<String> get makes {
    final values = (widget.game['vehicles'] as List)
        .map((v) => (v['make'] ?? '').toString().trim())
        .where((x) => x.isNotEmpty)
        .toSet().toList()..sort();
    return ['All Makes', ...values];
  }

  List<String> get classes {
    final values = (widget.game['vehicles'] as List)
        .map((v) => (v['class'] ?? '').toString().trim())
        .where((x) => x.isNotEmpty)
        .toSet().toList()..sort();
    return ['All Classes', ...values];
  }

  Future<void> chooseMake() async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xff111019),
      isScrollControlled: true,
      builder: (c) => SafeArea(
        child: SizedBox(
          height: MediaQuery.of(c).size.height * .72,
          child: ListView(
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20,18,20,8),
                child: Text('FILTER BY MAKE',
                  style: TextStyle(fontWeight: FontWeight.w900, color: gold)),
              ),
              ...makes.map((x) => ListTile(
                title: Text(x),
                trailing: x == make ? const Icon(Icons.check, color: purple) : null,
                onTap: () => Navigator.pop(c, x),
              )),
            ],
          ),
        ),
      ),
    );
    if (picked != null) setState(() => make = picked);
  }

  Future<void> chooseClass() async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xff111019),
      isScrollControlled: true,
      builder: (c) => SafeArea(
        child: SizedBox(
          height: MediaQuery.of(c).size.height * .72,
          child: ListView(
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20,18,20,8),
                child: Text('FILTER BY CLASS / TYPE',
                  style: TextStyle(fontWeight: FontWeight.w900, color: gold)),
              ),
              ...classes.map((x) => ListTile(
                title: Text(x),
                trailing: x == vehicleClass ? const Icon(Icons.check, color: purple) : null,
                onTap: () => Navigator.pop(c, x),
              )),
            ],
          ),
        ),
      ),
    );
    if (picked != null) setState(() => vehicleClass = picked);
  }

  @override
  Widget build(BuildContext c) {
    final vs = (widget.game['vehicles'] as List).where((v) {
      final text = '${v['year']} ${v['make']} ${v['model']} ${v['class']}'.toLowerCase();
      final queryOk = text.contains(q.toLowerCase().trim());
      final makeOk = make == 'All Makes' || v['make'] == make;
      final classOk = vehicleClass == 'All Classes' || v['class'] == vehicleClass;
      return queryOk && makeOk && classOk;
    }).toList();

    return Scaffold(
      appBar: AppBar(title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.game['name'],
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 19)),
          Text('${vs.length} of ${(widget.game['vehicles'] as List).length} vehicles',
            style: const TextStyle(fontSize: 10, color: Colors.white60)),
        ],
      )),
      body: CustomScrollView(slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(14,8,14,10),
          sliver: SliverToBoxAdapter(child: Column(children: [
            TextField(
              onChanged: (v) => setState(() => q = v),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: 'Search vehicles...',
                filled: true, fillColor: card,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: OutlinedButton.icon(
                onPressed: chooseMake,
                icon: const Icon(Icons.factory_outlined, size: 17),
                label: Text(make, overflow: TextOverflow.ellipsis),
              )),
              const SizedBox(width: 8),
              Expanded(child: OutlinedButton.icon(
                onPressed: chooseClass,
                icon: const Icon(Icons.category_outlined, size: 17),
                label: Text(vehicleClass, overflow: TextOverflow.ellipsis),
              )),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                onPressed: () => setState(() => grid = !grid),
                icon: Icon(grid ? Icons.grid_view_rounded : Icons.view_list_rounded),
              ),
            ]),
            if (make != 'All Makes' || vehicleClass != 'All Classes')
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => setState(() {
                    make = 'All Makes'; vehicleClass = 'All Classes';
                  }),
                  icon: const Icon(Icons.close, size: 16),
                  label: const Text('Clear filters'),
                ),
              ),
          ])),
        ),
        if (vs.isEmpty)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(30),
              child: Center(child: Text('No vehicles match those filters.',
                style: TextStyle(color: Colors.white60))),
            ),
          )
        else if (grid)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(14,0,14,24),
            sliver: SliverGrid(
              delegate: SliverChildBuilderDelegate(
                (c,i) => VehicleCard(gameId:widget.game['id'].toString(),v:vs[i],favourite:widget.favourites.contains(vehicleKey(vs[i])),onFavourite:()=>setState(()=>widget.onFavourite(vehicleKey(vs[i]))),tap:()=>openVehicle(c,vs[i])),
                childCount: vs.length,
              ),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount:2, childAspectRatio:.88,
                crossAxisSpacing:10, mainAxisSpacing:10),
            ),
          )
        else
          SliverList(delegate: SliverChildBuilderDelegate((c,i) {
            final v=vs[i];
            return ListTile(
              leading: SizedBox(width:78,height:54,child:VehicleImage(gameId:widget.game['id'].toString(),v:v)),
              title: Text('${v['make']} ${v['model']}'.trim()),
              subtitle: Text('${v['year']}  ${v['class'] ?? ''}'.trim()),
              trailing: const Icon(Icons.chevron_right),
              onTap:()=>openVehicle(c,v),
              titleAlignment:ListTileTitleAlignment.center,
            );
          }, childCount:vs.length)),
      ]),
    );
  }

  String vehicleKey(dynamic v)=>'${widget.game['id']}|${v['make']}|${v['model']}|${v['year']}';

  void openVehicle(BuildContext c,dynamic v) => Navigator.push(
    c, MaterialPageRoute(builder:(_) =>
      VehiclePage(game:widget.game,v:v,onSave:widget.onSave)));
}

class VehicleImageResolver {
  static String url(dynamic v) => (v['image'] ?? '').toString().trim();
}

class VehicleImage extends StatelessWidget {
  final String gameId; final dynamic v; final BoxFit fit;
  const VehicleImage({super.key,required this.gameId,required this.v,this.fit=BoxFit.contain});
  Widget fallback()=>Container(decoration:const BoxDecoration(gradient:LinearGradient(colors:[Color(0xff1d2335),Color(0xff351447)])),child:const Center(child:Icon(Icons.directions_car_filled_rounded,size:42,color:Colors.white38)));
  @override Widget build(BuildContext context) {
    final url=VehicleImageResolver.url(v);
    if(url.isEmpty) return fallback();
    return Container(decoration:const BoxDecoration(gradient:LinearGradient(begin:Alignment.topCenter,end:Alignment.bottomCenter,colors:[Color(0xff171622),Color(0xff09090f)])),padding:const EdgeInsets.all(8),alignment:Alignment.center,child:Image.network(url,fit:fit,alignment:Alignment.center,filterQuality:FilterQuality.high,loadingBuilder:(c,child,p)=>p==null?child:const Center(child:CircularProgressIndicator(strokeWidth:2)),errorBuilder:(_,__,___)=>fallback()));
  }
}

class VehicleCard extends StatelessWidget {
  final String gameId;
  final dynamic v;
  final VoidCallback tap,onFavourite; final bool favourite;
  const VehicleCard({super.key,required this.gameId,required this.v,required this.tap,required this.favourite,required this.onFavourite});

  @override
  Widget build(BuildContext c) => InkWell(
    onTap:tap,
    borderRadius:BorderRadius.circular(14),
    child:Container(
      clipBehavior:Clip.antiAlias,
      decoration:BoxDecoration(
        color:card,
        borderRadius:BorderRadius.circular(14),
        border:Border.all(color:Colors.white12)),
      child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Expanded(child:Stack(children:[Positioned.fill(child:VehicleImage(gameId:gameId,v:v)),Positioned(top:5,right:5,child:IconButton.filledTonal(onPressed:onFavourite,tooltip:favourite?'Remove favourite':'Add favourite',icon:Icon(favourite?Icons.star_rounded:Icons.star_border_rounded,color:favourite?gold:Colors.white70)))])),
        Padding(
          padding:const EdgeInsets.fromLTRB(10,9,10,10),
          child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Text('${v['make']} ${v['model']}'.trim(),
              maxLines:2,overflow:TextOverflow.ellipsis,
              style:const TextStyle(fontWeight:FontWeight.w900,fontSize:13)),
            const SizedBox(height:4),
            Wrap(spacing:5,runSpacing:4,children:[
              if((v['year']??'').toString().isNotEmpty)
                _MiniChip(v['year'].toString()),
              if((v['class']??'').toString().isNotEmpty)
                _MiniChip(v['class'].toString()),
            ]),
          ]),
        ),
      ]),
    ),
  );
}

class _MiniChip extends StatelessWidget {
  final String text;
  const _MiniChip(this.text);
  @override Widget build(BuildContext context)=>Container(
    padding:const EdgeInsets.symmetric(horizontal:6,vertical:3),
    decoration:BoxDecoration(
      color:Colors.white10,borderRadius:BorderRadius.circular(6)),
    child:Text(text,maxLines:1,overflow:TextOverflow.ellipsis,
      style:const TextStyle(fontSize:9,color:Colors.white70)));
}
class VehiclePage extends StatefulWidget{final dynamic game,v;final ValueChanged<Map<String,dynamic>> onSave;const VehiclePage({super.key,required this.game,required this.v,required this.onSave});@override State<VehiclePage> createState()=>_VehiclePage();}
class _VehiclePage extends State<VehiclePage>{List<dynamic> saved=[];int pageTab=1;
 String get vehicleName=>'${widget.v['make']} ${widget.v['model']} ${widget.v['year']}'.trim();
 @override void initState(){super.initState();_load();}
 Future<void> _load()async{final p=await SharedPreferences.getInstance();final all=jsonDecode(p.getString('setups')??'[]') as List; if(mounted)setState(()=>saved=all.where((x)=>x['gameId']==widget.game['id']&&x['vehicle']==vehicleName).toList());}
 @override Widget build(BuildContext c)=>Scaffold(appBar:AppBar(title:Text('${widget.v['make']} ${widget.v['model']}'.trim())),body:ListView(children:[
  Container(height:280,color:card,child:VehicleImage(gameId:widget.game['id'].toString(),v:widget.v,fit:BoxFit.contain)),
  Padding(padding:const EdgeInsets.all(18),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
   Text('${widget.v['make']} ${widget.v['model']}'.trim(),style:const TextStyle(fontSize:26,fontWeight:FontWeight.w900)),Text('${widget.v['year']??''}',style:const TextStyle(color:Colors.white60)),const SizedBox(height:20),
   SegmentedButton<int>(segments:const[ButtonSegment(value:0,label:Text('Overview')),ButtonSegment(value:1,label:Text('My Setups')),ButtonSegment(value:2,label:Text('Details'))],selected:{pageTab},showSelectedIcon:false,onSelectionChanged:(x)=>setState(()=>pageTab=x.first)),const SizedBox(height:10),
   if(pageTab==0)Container(width:double.infinity,padding:const EdgeInsets.all(16),decoration:BoxDecoration(color:card,borderRadius:BorderRadius.circular(12)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Label('OVERVIEW'),const SizedBox(height:8),Text(widget.game['name'],style:const TextStyle(color:gold,fontWeight:FontWeight.w800)),Text(vehicleName,style:const TextStyle(fontSize:17,fontWeight:FontWeight.w800)),if((widget.v['class']??'').toString().isNotEmpty)Text((widget.v['class']).toString(),style:const TextStyle(color:Colors.white60))])) else if(pageTab==2)Container(width:double.infinity,padding:const EdgeInsets.all(16),decoration:BoxDecoration(color:card,borderRadius:BorderRadius.circular(12)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Label('DETAILS'),const SizedBox(height:8),Text('Make: '+(widget.v['make']??'—').toString()),Text('Model: '+(widget.v['model']??'—').toString()),Text('Year: '+(widget.v['year']??'—').toString()),Text('Class / type: '+(widget.v['class']??'—').toString())])) else if(saved.isEmpty) Container(padding:const EdgeInsets.all(16),decoration:BoxDecoration(color:card,borderRadius:BorderRadius.circular(12)),child:const Text('No saved setups for this vehicle yet.',style:TextStyle(color:Colors.white60))) else ...saved.map((s)=>Card(color:card,child:ListTile(onTap:()async{await Navigator.push(c,MaterialPageRoute(builder:(_)=>EditSetup(game:widget.game,vehicle:vehicleName,onSave:widget.onSave,existing:Map<String,dynamic>.from(s))));await _load();},leading:const Icon(Icons.tune,color:purple),title:Text(s['title']??'Setup'),subtitle:Text('${s['type']??''} • ${s['savedAt']??''}'),trailing:const Icon(Icons.chevron_right)))),
   if(pageTab==1)const SizedBox(height:16),if(pageTab==1)SizedBox(width:double.infinity,child:FilledButton.icon(style:FilledButton.styleFrom(backgroundColor:const Color(0xff7113bd),foregroundColor:Colors.white,padding:const EdgeInsets.all(16)),onPressed:()async{await Navigator.push(c,MaterialPageRoute(builder:(_)=>EditSetup(game:widget.game,vehicle:vehicleName,onSave:widget.onSave)));await _load();},icon:const Icon(Icons.add),label:Text(saved.isEmpty?'Create New Setup':'Create Another Setup')))
  ]))]));}

class EditSetup extends StatefulWidget{final dynamic game;final String vehicle;final ValueChanged<Map<String,dynamic>> onSave;final Map<String,dynamic>? existing;const EditSetup({super.key,required this.game,required this.vehicle,required this.onSave,this.existing});@override State<EditSetup> createState()=>_EditSetup();}
class _EditSetup extends State<EditSetup>{final name=TextEditingController(text:'My Setup'),notes=TextEditingController();Map<String,dynamic>? schema;final Map<String,dynamic> values={};String type='Road';
 @override void initState(){super.initState();final e=widget.existing;if(e!=null){name.text=(e['title']??'My Setup').toString();notes.text=(e['notes']??'').toString();type=(e['type']??'Road').toString();if(e['values'] is Map)values.addAll(Map<String,dynamic>.from(e['values']));}_loadSchema();}
 Future<void> _loadSchema()async{final all=jsonDecode(await rootBundle.loadString('assets/catalog/game_schemas.json')) as Map<String,dynamic>;dynamic s=all[widget.game['id']];if(s is Map&&s['copy']!=null)s=all[s['copy']];if(mounted)setState(()=>schema=s);}
 @override Widget build(BuildContext c)=>Scaffold(appBar:AppBar(title:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(widget.existing==null?'New Setup':'Edit Setup'),Text(widget.vehicle,style:const TextStyle(fontSize:10,color:Colors.white60))])),body:Stack(children:[Positioned.fill(child:Opacity(opacity:.12,child:GameArt(game:widget.game))),Positioned.fill(child:Container(color:bg.withValues(alpha:.78))),ListView(padding:const EdgeInsets.all(16),children:[
  Text(widget.game['name'],style:const TextStyle(color:gold,fontWeight:FontWeight.w900,fontSize:18)),const SizedBox(height:8),_text(name,'Setup Name'),_text(notes,'Notes',3),const SizedBox(height:8),Wrap(spacing:8,children:['Road','Drift','Race','Drag','Rally','Off-road','Cruise'].map((x)=>ChoiceChip(label:Text(x),selected:type==x,onSelected:(_)=>setState(()=>type=x))).toList()),const SizedBox(height:16),
  if(schema==null)const Center(child:CircularProgressIndicator()) else ...(schema!['sections'] as List).map((sec)=>_section(sec)),
  const SizedBox(height:22),FilledButton.icon(style:FilledButton.styleFrom(backgroundColor:const Color(0xff7113bd),foregroundColor:Colors.white,padding:const EdgeInsets.all(16)),onPressed:(){widget.onSave({'id':widget.existing?['id']??DateTime.now().microsecondsSinceEpoch.toString(),'gameId':widget.game['id'],'game':widget.game['name'],'vehicle':widget.vehicle,'title':name.text.trim().isEmpty?'My Setup':name.text.trim(),'type':type,'notes':notes.text,'values':values,'savedAt':DateTime.now().toIso8601String().substring(0,10)});Navigator.pop(c);},icon:const Icon(Icons.check),label:const Text('Save Setup'))
 ] )]));
 Widget _section(dynamic sec)=>Container(margin:const EdgeInsets.only(bottom:14),padding:const EdgeInsets.all(14),decoration:BoxDecoration(color:card.withValues(alpha:.92),borderRadius:BorderRadius.circular(14),border:Border.all(color:purple.withValues(alpha:.25))),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Label(sec['title'].toString().toUpperCase()),const SizedBox(height:10),...(sec['fields'] as List).map((f)=>_field(f))]));
 Widget _field(dynamic f){final id=f['id'].toString(),label=f['label'].toString(),type=f['type']??'text';if(type=='toggle'){final v=values[id]??false;return SwitchListTile(contentPadding:EdgeInsets.zero,title:Text(label),value:v,onChanged:(x)=>setState(()=>values[id]=x));}if(type=='choice'){final opts=List<String>.from(f['options']);final cur=values[id]?.toString();return Padding(padding:const EdgeInsets.symmetric(vertical:5),child:DropdownButtonFormField<String>(initialValue:opts.contains(cur)?cur:null,decoration:InputDecoration(labelText:label,filled:true,fillColor:card2,border:const OutlineInputBorder()),items:opts.map((x)=>DropdownMenuItem(value:x,child:Text(x))).toList(),onChanged:(x)=>setState(()=>values[id]=x)));}if(type=='number'){final min=(f['min'] as num).toDouble(),max=(f['max'] as num).toDouble(),step=(f['step'] as num).toDouble();double v=(values[id] as num?)?.toDouble()??min;final divisions=((max-min)/step).round();String shown=step<1?v.toStringAsFixed(step<0.1?2:1):v.round().toString();return Padding(padding:const EdgeInsets.symmetric(vertical:4),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Row(children:[Expanded(child:Text(label,style:const TextStyle(fontSize:12))),Text('$shown${f['unit']??''}',style:const TextStyle(color:gold,fontWeight:FontWeight.bold))]),Slider(value:v.clamp(min,max),min:min,max:max,divisions:divisions>0?divisions:null,onChanged:(x)=>setState(()=>values[id]=(x/step).round()*step))]));}return Padding(padding:const EdgeInsets.symmetric(vertical:5),child:TextFormField(initialValue:values[id]?.toString()??'',onChanged:(x)=>values[id]=x,decoration:InputDecoration(labelText:label,filled:true,fillColor:card2,border:const OutlineInputBorder())));}
 Widget _text(TextEditingController c,String l,[int lines=1])=>Padding(padding:const EdgeInsets.symmetric(vertical:6),child:TextField(controller:c,maxLines:lines,decoration:InputDecoration(labelText:l,filled:true,fillColor:card.withValues(alpha:.95),border:OutlineInputBorder(borderRadius:BorderRadius.circular(8)))));
}

class MySetups extends StatefulWidget {
 final List items,games; final ValueChanged<dynamic> onDelete; final ValueChanged<Map<String,dynamic>> onSave;
 const MySetups({super.key,required this.items,required this.games,required this.onSave,required this.onDelete});
 @override State<MySetups> createState()=>_MySetupsState();
}
class _MySetupsState extends State<MySetups>{
 dynamic _gameFor(dynamic x){for(final g in widget.games){if(g['id']==x['gameId']||g['name']==x['game'])return g;}return null;}
 Future<void> _open(dynamic x)async{final g=_gameFor(x);if(g==null){if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Game catalogue entry not found for this setup.')));return;}await Navigator.push(context,MaterialPageRoute(builder:(_)=>EditSetup(game:g,vehicle:(x['vehicle']??'').toString(),onSave:widget.onSave,existing:Map<String,dynamic>.from(x))));if(mounted)setState((){});}
 void _duplicate(dynamic x){final copy=Map<String,dynamic>.from(x);copy['id']=DateTime.now().microsecondsSinceEpoch.toString();copy['title']="${x['title']??'Setup'} Copy";copy['savedAt']=DateTime.now().toIso8601String().substring(0,10);widget.onSave(copy);setState((){});}
 @override Widget build(BuildContext context)=>ListView(padding:const EdgeInsets.all(18),children:[
  const Text('My Setups',style:TextStyle(fontSize:28,fontWeight:FontWeight.w900)),const SizedBox(height:4),
  Text("${widget.items.length} saved setup${widget.items.length==1?'':'s'}",style:const TextStyle(color:Colors.white60)),const SizedBox(height:12),
  if(widget.items.isEmpty)const Text('No saved setups yet.',style:TextStyle(color:Colors.white60)) else ...widget.items.map((x)=>Card(color:card,child:ListTile(
   onTap:()=>_open(x),leading:const Icon(Icons.tune,color:purple),title:Text(x['title']??'Setup'),subtitle:Text("${x['game']??''}\n${x['vehicle']??''}"),isThreeLine:true,
   trailing:PopupMenuButton<String>(onSelected:(v){if(v=='edit')_open(x);if(v=='duplicate')_duplicate(x);if(v=='delete')widget.onDelete(x);},itemBuilder:(_)=>const[
    PopupMenuItem(value:'edit',child:Text('Edit')),PopupMenuItem(value:'duplicate',child:Text('Duplicate')),PopupMenuItem(value:'delete',child:Text('Delete'))]))))
 ]);
}
class Hardware extends StatefulWidget{const Hardware({super.key});@override State<Hardware> createState()=>_Hardware();}
class _Hardware extends State<Hardware>{
 List<dynamic> makers=[],profiles=[]; Map<String,dynamic> recommended={}; String q='';
 @override void initState(){super.initState();load();}
 Future<void> load()async{
  final raw=jsonDecode(await rootBundle.loadString('assets/catalog/hardware.json'));
  final p=await SharedPreferences.getInstance();
  makers=raw['manufacturers']; recommended=Map<String,dynamic>.from(raw['recommended_profiles']??{}); profiles=jsonDecode(p.getString('hw_profiles')??'[]');
  if(mounted)setState((){});
 }
 Future<void> saveProfile(dynamic maker,dynamic dev)async{
  double rotation=dev['name'].toString().contains('RS50')?900:900, strength=dev['name'].toString().contains('RS50')?8:((dev['torque_nm'] as num?)?.toDouble()??5), damper=15, filter=10, friction=0, inertia=0, spring=0, audio=0, brakeForce=50;
  bool trueforce=true, centering=false;String compatibilityMode='RS';String platform=(dev['platforms'] as List).isNotEmpty?dev['platforms'][0].toString():'PC';final notes=TextEditingController();
  await showDialog<void>(context:context,builder:(dc)=>StatefulBuilder(builder:(dc,setD)=>AlertDialog(
   title:Text('${maker['name']} ${dev['name']}'),content:ConstrainedBox(constraints:const BoxConstraints(maxWidth:420),child:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[
    Text('${dev['drive']}${dev['torque_nm']!=null?' • ${dev['torque_nm']} Nm':''}',style:const TextStyle(color:gold)),const SizedBox(height:12),
    Wrap(spacing:6,runSpacing:6,children:(dev['platforms'] as List).map<Widget>((x)=>Chip(label:Text(x.toString(),style:const TextStyle(fontSize:11)))).toList()),
    if(dev['name'].toString().contains('RS50')) Padding(padding:const EdgeInsets.only(top:10),child:DropdownButtonFormField<String>(initialValue:compatibilityMode,decoration:const InputDecoration(labelText:'Compatibility Mode'),items:['RS','PRO'].map((x)=>DropdownMenuItem(value:x,child:Text(x))).toList(),onChanged:(x){if(x!=null)setD(()=>compatibilityMode=x);})),
    _hwSlider('Operating Range / Steering Angle',rotation,90,1080,10,'°',(x)=>setD(()=>rotation=x)),
    _hwSlider(dev['name'].toString().contains('RS50')?'Torque / Strength':'Overall Force Feedback',strength,0,dev['torque_nm']!=null?(dev['torque_nm'] as num).toDouble():11,.1,dev['torque_nm']!=null?' Nm':'',(x)=>setD(()=>strength=x)),
    _hwSlider('Damping',damper,0,100,1,'%',(x)=>setD(()=>damper=x)),
    _hwSlider('Force Feedback Filter',filter,0,100,1,'',(x)=>setD(()=>filter=x)),
    if(!dev['name'].toString().contains('RS50')) _hwSlider('Friction',friction,0,100,1,'%',(x)=>setD(()=>friction=x)),
    if(!dev['name'].toString().contains('RS50')) _hwSlider('Inertia',inertia,0,100,1,'%',(x)=>setD(()=>inertia=x)),
    if(!dev['name'].toString().contains('RS50')) _hwSlider('Spring / Centering Spring',spring,0,100,1,'%',(x)=>setD(()=>spring=x)),
    _hwSlider('Audio / TRUEFORCE Effects',audio,0,100,1,'%',(x)=>setD(()=>audio=x)),
    if(!dev['name'].toString().contains('RS50')) _hwSlider('Brake Force / Load Cell',brakeForce,0,100,1,'%',(x)=>setD(()=>brakeForce=x)),
    SwitchListTile(contentPadding:EdgeInsets.zero,title:const Text('TRUEFORCE / High-frequency effects'),value:trueforce,onChanged:(x)=>setD(()=>trueforce=x)),
    if(!dev['name'].toString().contains('RS50')) SwitchListTile(contentPadding:EdgeInsets.zero,title:const Text('Centering spring in non-FFB games'),value:centering,onChanged:(x)=>setD(()=>centering=x)),
    if(recommended[dev['name']] is Map)...[
     const SizedBox(height:14),
     const Divider(),
     const Text('OFFICIAL GAME BASELINES',style:TextStyle(color:gold,fontWeight:FontWeight.w900,fontSize:12)),
     const SizedBox(height:6),
     ...(Map<String,dynamic>.from(recommended[dev['name']]['games']??{}).entries.map((e){
       final p=Map<String,dynamic>.from(e.value);
       final gameNames={'fh5':'Forza Horizon 5','carx':'CarX Drift Racing Online','wrc':'EA SPORTS WRC','gt7':'Gran Turismo 7','assetto':'Assetto Corsa'};
       final rot=p['rotation']; final tf=p['audio'];
       return Container(margin:const EdgeInsets.only(bottom:6),padding:const EdgeInsets.all(10),decoration:BoxDecoration(color:card2,borderRadius:BorderRadius.circular(9)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text(gameNames[e.key]??e.key,style:const TextStyle(fontWeight:FontWeight.w800)),
        const SizedBox(height:3),
        Text('Mode: ${p['compatibilityMode']}  •  Filter: ${p['filter']}  •  Dampener: ${p['damping']}  •  Angle: $rot${rot is num?'°':''}${tf==null?'':'  •  TF Audio: $tf'}',style:const TextStyle(fontSize:11,color:Colors.white70)),
        const SizedBox(height:6),
        OutlinedButton.icon(onPressed:(){setD((){compatibilityMode=p['compatibilityMode'].toString();filter=(p['filter'] as num).toDouble();damper=(p['damping'] as num).toDouble();if(rot is num)rotation=rot.toDouble();if(tf is num)audio=tf.toDouble();});},icon:const Icon(Icons.download_rounded,size:16),label:const Text('Apply baseline'))
       ]));
     })),
    ],
    TextField(controller:notes,maxLines:3,decoration:const InputDecoration(labelText:'Notes (optional)'))
   ]))),actions:[TextButton(onPressed:()=>Navigator.pop(dc),child:const Text('Cancel')),FilledButton(onPressed:(){
    profiles.add({'maker':maker['name'],'device':dev['name'],'platform':platform,'compatibilityMode':compatibilityMode,'rotation':rotation.round(),'strength':strength,'damping':damper.round(),'filter':filter.round(),'friction':friction.round(),'inertia':inertia.round(),'spring':spring.round(),'audio':audio.round(),'brakeForce':brakeForce.round(),'trueforce':trueforce,'centering':centering,'notes':notes.text});Navigator.pop(dc);},child:const Text('Save Profile'))])));
  final p=await SharedPreferences.getInstance(); await p.setString('hw_profiles',jsonEncode(profiles)); if(mounted)setState((){});
 }
 Widget _hwSlider(String label,double value,double min,double max,double step,String unit,ValueChanged<double> onChanged){final div=((max-min)/step).round();final shown=step<1?value.toStringAsFixed(1):value.round().toString();return Padding(padding:const EdgeInsets.only(top:10),child:Column(children:[Row(children:[Expanded(child:Text(label,style:const TextStyle(fontSize:12))),Text('$shown$unit',style:const TextStyle(color:gold,fontWeight:FontWeight.bold))]),Slider(value:value.clamp(min,max),min:min,max:max,divisions:div>0?div:null,onChanged:onChanged)]));}
 @override Widget build(BuildContext c){
  final filtered=<Map<String,dynamic>>[];
  for(final m in makers){for(final d in m['devices']){if(('${m['name']} ${d['name']}').toLowerCase().contains(q.toLowerCase()))filtered.add({'m':m,'d':d});}}
  return ListView(padding:const EdgeInsets.all(18),children:[
   const Text('Hardware',style:TextStyle(fontSize:28,fontWeight:FontWeight.w900)),
   const Text('Choose your exact wheel or wheelbase, then save game-specific settings.',style:TextStyle(color:gold,fontSize:12)),
   const SizedBox(height:14),
   TextField(onChanged:(v)=>setState(()=>q=v),decoration:InputDecoration(prefixIcon:const Icon(Icons.search),hintText:'Search G29, RS50, R12, T300...',filled:true,fillColor:card,border:OutlineInputBorder(borderRadius:BorderRadius.circular(10),borderSide:BorderSide.none))),
   if(profiles.isNotEmpty)...[const SizedBox(height:18),const Label('MY HARDWARE PROFILES'),const SizedBox(height:8),
    ...profiles.map((x)=>Card(color:card,child:ListTile(leading:const Icon(Icons.sports_esports,color:purple),title:Text('${x['maker']} ${x['device']}'),subtitle:Text('Rotation: ${x['rotation']??'—'}°  •  Strength: ${x['strength']??x['ffb']??'—'}'))))],
   const SizedBox(height:18),const Label('HARDWARE CATALOGUE'),const SizedBox(height:8),
   ...filtered.map((x){final m=x['m'],d=x['d'];return Card(color:card,child:ListTile(
    onTap:()=>saveProfile(m,d),leading:const Icon(Icons.settings_input_component_rounded,color:gold),
    title:Text('${m['name']} ${d['name']}',style:const TextStyle(fontWeight:FontWeight.w800)),
    subtitle:Text('${d['drive']}${d['torque_nm']!=null?' • ${d['torque_nm']} Nm':''}\n${(d['platforms'] as List).join(' • ')}',maxLines:2),
    trailing:const Icon(Icons.add_circle_outline,color:purple)));})
  ]);
 }
}
