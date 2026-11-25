import java.io.*;
import java.nio.file.*;
import java.util.*;

/**
 * RQ4: how many extra terms does a missed course add to graduation?
 * Java version of rq4_term_simulation.py (same rules, same output file).
 * Reads prereq_groups.csv, coreq_groups.csv, degree_requirements.csv and course_offerings.csv,
 * writes output/rq4_term_delay.csv.
 * Run from the project root:  java rq4_term_simulation.java
 */
public class Rq4TermSimulation {
    static final Set<String> SPECIAL = Set.of("HS_ENTRY");
    static final Map<String, Integer> STANDING = Map.of("STANDING_3", 3, "STANDING_4", 4);
    static final Set<String> UNAVAILABLE = Set.of("COSC 223", "COSC 413", "COSC 417");
    static final String[] TERMS = {"T1", "T2", "S"};
    static final String[] LOAD_NAMES = {"5 courses", "6 courses"};
    static final int[] LOAD_CREDITS = {15, 18};
    static final int CREDITS_TO_GRADUATE = 120;
    static final String[] KEY_COURSES = {"COSC 111", "COSC 121", "COSC 122", "COSC 123", "COSC 211", "COSC 221",
            "COSC 222", "COSC 304", "COSC 310", "COSC 320", "COSC 341"};

    static Map<String, List<List<Set<String>>>> PREREQ, COREQ;
    static List<Map<String, String>> REQS;
    static Map<String, Map<String, Set<String>>> OFFERINGS = new HashMap<>();

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

    /** course -> routes -> groups -> members (OR inside a group, AND across groups, OR across routes). */
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

    static boolean satisfied(List<List<Set<String>>> routes, Set<String> done) {
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

    static List<List<String>> core(String program) {
        List<List<String>> out = new ArrayList<>();
        for (Map<String, String> r : REQS)
            if (r.get("program").equals(program)
                    && (r.get("kind").equals("mandatory") || r.get("kind").equals("choice"))
                    && !r.get("req_id").startsWith("BSC03"))
                out.add(Arrays.asList(r.get("options").split("\\|")));
        return out;
    }

    static int credits(String course) { return course.equals("COSC 499") ? 6 : 3; }

    /** Core options plus everything that can lead to them. */
    static Set<String> neededCourses(String program) {
        Set<String> need = new HashSet<>();
        for (var opts : core(program)) need.addAll(opts);
        Deque<String> stack = new ArrayDeque<>(need);
        while (!stack.isEmpty()) {
            String c = stack.pop();
            for (var logic : List.of(PREREQ, COREQ))
                for (var route : logic.getOrDefault(c, List.of()))
                    for (var group : route)
                        for (String m : group)
                            if (!SPECIAL.contains(m) && !STANDING.containsKey(m) && !need.contains(m) && !UNAVAILABLE.contains(m)) {
                                need.add(m);
                                stack.push(m);
                            }
        }
        return need;
    }

    static Map<String, Set<String>> unlocks;
    static Map<String, Integer> memo;

    static int depth(String c) {
        if (!memo.containsKey(c)) {
            memo.put(c, 0);
            int best = 0;
            for (String u : unlocks.getOrDefault(c, Set.of())) best = Math.max(best, depth(u) + 1);
            memo.put(c, best);
        }
        return memo.get(c);
    }

    /** Longest chain of needed courses that depends on each course (used as priority). */
    static Map<String, Integer> chainDepth(Set<String> need) {
        unlocks = new HashMap<>();
        for (String c : need)
            for (var logic : List.of(PREREQ, COREQ))
                for (var route : logic.getOrDefault(c, List.of()))
                    for (var group : route)
                        for (String m : group)
                            if (need.contains(m)) unlocks.computeIfAbsent(m, k -> new HashSet<>()).add(c);
        memo = new HashMap<>();
        Map<String, Integer> out = new HashMap<>();
        for (String c : need) out.put(c, depth(c));
        return out;
    }

    /** Number of terms attended until the degree is complete (-1 if never). Missed = course failed on first attempt. */
    static int termsToGraduate(String program, String pattern, boolean summer, int load, String missed) {
        Map<String, Set<String>> offered = pattern == null ? Map.of() : OFFERINGS.get(pattern);
        Set<String> need = neededCourses(program);
        Map<String, Integer> depth = chainDepth(need);
        Set<String> done = new HashSet<>();
        int totalCredits = 0, attended = 0;
        Integer firstMiss = null;
        for (int t = 0; t < 60; t++) {
            String term = TERMS[t % 3];
            int year = t / 3 + 1;
            if (term.equals("S") && !summer) continue;
            for (var e : STANDING.entrySet()) if (year >= e.getValue()) done.add(e.getKey());
            Set<String> before = new HashSet<>(done);
            int taken = 0, used = 0;
            while (true) {
                List<String> options = new ArrayList<>();
                for (String c : need) {
                    if (done.contains(c) || UNAVAILABLE.contains(c)) continue;
                    if (offered.containsKey(c) && !offered.get(c).contains(term)) continue;
                    Set<String> nowDone = new HashSet<>(before);
                    nowDone.addAll(done);
                    if (!satisfied(PREREQ.get(c), before) || !satisfied(COREQ.get(c), nowDone)) continue;
                    if (c.equals(missed) && (firstMiss == null || firstMiss == t)) { firstMiss = t; continue; }
                    if (used + credits(c) <= load) options.add(c);
                }
                if (options.isEmpty()) break;
                options.sort(Comparator.comparingInt((String x) -> -depth.get(x)).thenComparing(x -> x));
                String c = options.get(0);
                done.add(c);
                taken++;
                used += credits(c);
                totalCredits += credits(c);
            }
            if (!term.equals("S")) totalCredits += load - used;   // elective credit fills the rest of a Winter term
            if (taken > 0 || !term.equals("S")) attended++;
            boolean coreDone = true;
            for (var opts : core(program)) {
                boolean any = false;
                for (String o : opts) if (done.contains(o)) { any = true; break; }
                if (!any) { coreDone = false; break; }
            }
            if (coreDone && totalCredits >= CREDITS_TO_GRADUATE) return attended;
        }
        return -1;
    }

    public static void main(String[] args) throws IOException {
        Path root = Paths.get(args.length > 0 ? args[0] : ".");
        PREREQ = readLogic(root.resolve("prereq_groups.csv"));
        COREQ = readLogic(root.resolve("coreq_groups.csv"));
        REQS = readCsv(root.resolve("degree_requirements.csv"));
        for (Map<String, String> r : readCsv(root.resolve("course_offerings.csv"))) {
            String terms = r.get("terms_offered").trim();
            Set<String> s = terms.isEmpty() ? new HashSet<>() : new HashSet<>(Arrays.asList(terms.split("\\s+")));
            OFFERINGS.computeIfAbsent(r.get("pattern"), k -> new HashMap<>()).put(r.get("course"), s);
        }

        String[] patterns = {"2025-26", "2022-23"};
        List<String[]> rows = new ArrayList<>();
        for (String pattern : patterns)
            for (boolean summer : new boolean[]{false, true})
                for (int li = 0; li < LOAD_NAMES.length; li++)
                    for (String program : new String[]{"BSc", "BA"}) {
                        int base = termsToGraduate(program, pattern, summer, LOAD_CREDITS[li], null);
                        for (String course : KEY_COURSES) {
                            int extra = termsToGraduate(program, pattern, summer, LOAD_CREDITS[li], course) - base;
                            rows.add(new String[]{pattern, summer ? "yes" : "no", LOAD_NAMES[li], program,
                                    String.valueOf(base), course, String.valueOf(extra)});
                        }
                    }

        Path out = root.resolve("output").resolve("rq4_term_delay.csv");
        Files.createDirectories(out.getParent());
        try (PrintWriter w = new PrintWriter(Files.newBufferedWriter(out))) {
            w.print("pattern,summer,load,program,terms_to_graduate,missed_course,extra_terms\r\n");
            for (String[] r : rows) w.print(String.join(",", r) + "\r\n");
        }

        // short summary: only courses with a delay
        for (String pattern : patterns)
            for (String summer : new String[]{"no", "yes"})
                for (String load : LOAD_NAMES)
                    for (String program : new String[]{"BSc", "BA"}) {
                        List<String[]> sel = new ArrayList<>();
                        for (String[] r : rows)
                            if (r[0].equals(pattern) && r[1].equals(summer) && r[2].equals(load) && r[3].equals(program)) sel.add(r);
                        StringBuilder d = new StringBuilder();
                        for (String[] r : sel)
                            if (!r[6].equals("0")) { if (d.length() > 0) d.append(", "); d.append(r[5]).append(" +").append(r[6]); }
                        System.out.printf("%s | Summer %s | %s | %s: graduate in %s terms | %s%n",
                                pattern, summer, load, program, sel.get(0)[4], d.length() == 0 ? "no delay" : d);
                    }
    }
}
