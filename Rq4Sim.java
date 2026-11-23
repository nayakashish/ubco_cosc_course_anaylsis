import java.io.*;
import java.nio.file.*;
import java.util.*;

/** RQ4 term-offering simulation. Usage: java Rq4Sim.java <repo-folder> */
public class Rq4Sim {
    static final Set<String> SPECIAL = Set.of("HS_ENTRY");
    static final Set<String> STAND = Set.of("STANDING_3", "STANDING_4");
    static final Set<String> UNAVAIL = Set.of("COSC 223", "COSC 413", "COSC 417");
    static final int HORIZON = 40;

    // course -> routes -> groups -> members (OR inside a group, AND across groups, OR across routes)
    static Map<String, List<List<Set<String>>>> PRE, CO;
    static List<Map<String, String>> REQ;

    static List<Map<String, String>> readCsv(Path p) throws IOException {
        List<Map<String, String>> rows = new ArrayList<>();
        List<String> lines = Files.readAllLines(p);
        String[] header = splitCsv(lines.get(0));
        for (int i = 1; i < lines.size(); i++) {
            if (lines.get(i).isBlank()) continue;
            String[] f = splitCsv(lines.get(i));
            Map<String, String> m = new HashMap<>();
            for (int j = 0; j < header.length; j++) m.put(header[j], j < f.length ? f[j] : "");
            rows.add(m);
        }
        return rows;
    }

    static String[] splitCsv(String line) {
        List<String> out = new ArrayList<>();
        StringBuilder sb = new StringBuilder();
        boolean q = false;
        for (int i = 0; i < line.length(); i++) {
            char c = line.charAt(i);
            if (q) {
                if (c == '"' && i + 1 < line.length() && line.charAt(i + 1) == '"') { sb.append('"'); i++; }
                else if (c == '"') q = false;
                else sb.append(c);
            } else if (c == '"') q = true;
            else if (c == ',') { out.add(sb.toString()); sb.setLength(0); }
            else sb.append(c);
        }
        out.add(sb.toString());
        return out.toArray(new String[0]);
    }

    static Map<String, List<List<Set<String>>>> readLogic(Path p) throws IOException {
        Map<String, Map<String, Map<String, Set<String>>>> t = new LinkedHashMap<>();
        for (Map<String, String> r : readCsv(p))
            t.computeIfAbsent(r.get("course"), k -> new LinkedHashMap<>())
             .computeIfAbsent(r.get("route"), k -> new LinkedHashMap<>())
             .computeIfAbsent(r.get("group"), k -> new LinkedHashSet<>())
             .add(r.get("member"));
        Map<String, List<List<Set<String>>>> out = new HashMap<>();
        for (var e : t.entrySet()) {
            List<List<Set<String>>> routes = new ArrayList<>();
            for (var route : e.getValue().values()) routes.add(new ArrayList<>(route.values()));
            out.put(e.getKey(), routes);
        }
        return out;
    }

    /** mandatory/choice requirements of a degree (BSC03 English rows excluded). */
    static List<List<String>> core(String prog) {
        List<List<String>> out = new ArrayList<>();
        for (Map<String, String> r : REQ)
            if (r.get("program").equals(prog)
                    && (r.get("kind").equals("mandatory") || r.get("kind").equals("choice"))
                    && !r.get("req_id").startsWith("BSC03"))
                out.add(Arrays.asList(r.get("options").split("\\|")));
        return out;
    }

    static boolean sat(List<List<Set<String>>> routes, Set<String> done) {
        if (routes == null || routes.isEmpty()) return true;
        for (var route : routes) {
            boolean all = true;
            for (Set<String> group : route) {
                boolean any = false;
                for (String m : group) if (SPECIAL.contains(m) || done.contains(m)) { any = true; break; }
                if (!any) { all = false; break; }
            }
            if (all) return true;
        }
        return false;
    }

    static Map<String, Set<String>> offer(String[][] rows) {
        Map<String, Set<String>> m = new HashMap<>();
        for (String[] r : rows) m.put(r[0], new HashSet<>(Arrays.asList(r).subList(1, r.length)));
        return m;
    }

    static final Map<String, Set<String>> REF = offer(new String[][]{
        {"COSC 111","W1","W2","S"},{"COSC 121","W1","W2","S"},{"COSC 122","W1"},{"COSC 123","W2"},
        {"COSC 211","W1"},{"COSC 221","W1","W2"},{"COSC 222","W1","W2","S"},{"COSC 304","W1","S"},
        {"COSC 310","W1","W2"},{"COSC 315","W2"},{"COSC 320","W2"},{"COSC 341","W1","W2"},{"COSC 499","W1","S"}});
    static final Map<String, Set<String>> OLD = offer(new String[][]{
        {"COSC 111","W1","W2","S"},{"COSC 121","W2","S"},{"COSC 122","W1"},{"COSC 123","W2"},
        {"COSC 211","W2"},{"COSC 221","W1","W2"},{"COSC 222","W1","S"},{"COSC 304","W1","S"},
        {"COSC 310","W2"},{"COSC 315","W2"},{"COSC 320","W2"},{"COSC 341","W2"},{"COSC 499","W1","S"}});

    static Set<String> allCourses() {
        Set<String> all = new TreeSet<>(PRE.keySet());
        all.addAll(CO.keySet());
        for (String p : new String[]{"BSc", "BA"}) for (var opts : core(p)) all.addAll(opts);
        for (var routes : List.of(PRE.values(), CO.values()))
            for (var rs : routes) for (var r : rs) for (var g : r) all.addAll(g);
        return all;
    }

    /** Greedy earliest schedule, no course-load cap. skip = course whose first eligible attempt is failed/missed. */
    static Map<String, Integer> simulate(Map<String, Set<String>> off, String[] cycle, String skip) {
        Set<String> done = new HashSet<>();
        Map<String, Integer> fin = new HashMap<>();
        Integer skippedAt = null;
        Set<String> all = allCourses();
        for (int t = 0; t < HORIZON; t++) {
            String term = cycle[t % cycle.length];
            int year = 0;
            for (int u = 0; u <= t; u++) if (cycle[u % cycle.length].equals("W1")) year++;
            if (year >= 3) done.add("STANDING_3");
            if (year >= 4) done.add("STANDING_4");
            Set<String> before = new HashSet<>(done);
            boolean changed = true;
            while (changed) {
                changed = false;
                for (String c : all) {
                    if (done.contains(c) || UNAVAIL.contains(c) || SPECIAL.contains(c) || STAND.contains(c)) continue;
                    if (off.containsKey(c) && !off.get(c).contains(term)) continue;
                    if (!sat(PRE.get(c), before)) continue;
                    Set<String> nowOk = new HashSet<>(before); nowOk.addAll(done);   // corequisites: same term allowed
                    if (!sat(CO.get(c), nowOk)) continue;
                    if (c.equals(skip)) {
                        if (skippedAt == null) skippedAt = t;
                        if (skippedAt == t) continue;
                    }
                    done.add(c); fin.put(c, t); changed = true;
                }
            }
        }
        return fin;
    }

    /** Term index (0-based) when the whole core of `prog` is finished; -1 if impossible. */
    static int finish(Map<String, Integer> fin, String prog) {
        int t = 0;
        for (var opts : core(prog)) {
            int best = Integer.MAX_VALUE;
            for (String o : opts) if (fin.containsKey(o)) best = Math.min(best, fin.get(o));
            if (best == Integer.MAX_VALUE) return -1;
            t = Math.max(t, best);
        }
        return t;
    }

    public static void main(String[] args) throws IOException {
        Path root = Paths.get(args.length > 0 ? args[0] : ".");
        PRE = readLogic(root.resolve("prereq_groups.csv"));
        CO = readLogic(root.resolve("coreq_groups.csv"));
        REQ = readCsv(root.resolve("degree_requirements.csv"));

        String[] cands = {"COSC 111","COSC 121","COSC 122","COSC 123","COSC 211","COSC 221",
                          "COSC 222","COSC 304","COSC 310","COSC 320","COSC 341"};
        Map<String, Map<String, Set<String>>> patterns = new LinkedHashMap<>();
        patterns.put("2025-26", REF); patterns.put("2022-23", OLD);
        Map<String, String[]> cycles = new LinkedHashMap<>();
        cycles.put("no Summer", new String[]{"W1", "W2"});
        cycles.put("with Summer", new String[]{"W1", "W2", "S"});

        for (var p : patterns.entrySet())
            for (var cy : cycles.entrySet()) {
                String[] cyc = cy.getValue();
                Map<String, Integer> ideal = simulate(new HashMap<>(), cyc, null);
                Map<String, Integer> base = simulate(p.getValue(), cyc, null);
                System.out.printf("%n=== offering %s | %s ===%n", p.getKey(), cy.getKey());
                for (String prog : new String[]{"BSc", "BA"}) {
                    int ib = finish(ideal, prog), rb = finish(base, prog);
                    System.out.printf("%s: min terms to finish core (ideal, all offered every term) = %d; with real offerings = %d  (+%d)%n",
                            prog, ib + 1, rb + 1, rb - ib);
                }
                for (String prog : new String[]{"BSc", "BA"}) {
                    System.out.printf("--- %s: extra terms vs the same schedule if the course is missed/failed once%n", prog);
                    List<Object[]> rows = new ArrayList<>();
                    for (String c : cands) {
                        int real = finish(simulate(p.getValue(), cyc, c), prog) - finish(base, prog);
                        int idl = finish(simulate(new HashMap<>(), cyc, c), prog) - finish(ideal, prog);
                        rows.add(new Object[]{c, real, idl});
                    }
                    rows.sort((a, b) -> (int) b[1] - (int) a[1]);
                    for (Object[] r : rows)
                        System.out.printf("  %s: +%d terms (real offerings)   +%d (if offered every term)%n", r[0], r[1], r[2]);
                }
            }
    }
}
