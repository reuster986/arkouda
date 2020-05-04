prototype module UnitTestIn1d
{
    use In1d;
    
    use Random;
    use Time only;

    use BlockDist;


    // fill a with integers from interval aMin..(aMax-1)
    proc fillRandInt(a: [?aD] ?t, aMin: t, aMax: t) {

        var t1 = Time.getCurrentTime();
        
        coforall loc in Locales {
            on loc {
                var R = new owned RandomStream(real); R.getNext();
                [i in a.localSubdomain()] a[i] = (R.getNext() * (aMax -aMin) + aMin):t;
            }
        }

        writeln("compute time = ", Time.getCurrentTime() - t1,"sec"); try! stdout.flush();
    }

    proc createRandomStrings(n: int, m: int, minLen: int, maxLen: int, coverage: real, st: borrowed SymTab) throws {
      var t = new Timer();
      t.start();
      const nVals:int = (m/coverage):int;
      writeln("nVals = ", nVals);
      var uLens = makeDistArray(nVals, int);
      // Add 1 for null byte
      fillRandInt(uLens, minLen+1, maxLen+1);
      const uBytes = + reduce uLens;
      var uSegs = (+ scan uLens) - uLens;
      var uVals = makeDistArray(uBytes, uint(8));
      fillRandInt(uVals, 65:uint(8), 90:uint(8)); // ascii uppercase
      // Terminate with null bytes
      [(s, l) in zip(uSegs, uLens)] uVals[s+l-1] = 0:uint(8);
      var uStr = new owned SegString(uSegs, uVals, st);
      // Indices to sample from unique strings
      var inds = makeDistArray(n, int);
      fillRandInt(inds, 0, nVals);
      var (segs, vals) = uStr[inds];
      var str1 = new shared SegString(segs, vals, st);
      writeln("compute time = ", t.elapsed());
      writeln("str1 = ");
      str1.show(5);
      var inds2 = makeDistArray(m, int);
      // [(i, ii) in zip(inds2.domain, inds2)] ii = i;
      inds2 = 0..#m;
      var (segs2, vals2) = uStr[inds2];
      var str2 = new shared SegString(segs2, vals2, st);
      writeln("str2 = ");
      str2.show(5);
      return (str1, str2);
    }

    proc test_in1d(n: int, m: int, nVals: int) {

        writeln((n, m, nVals)); try! stdout.flush();

        const aDom = newBlockDom({0..#n});

        var a: [aDom] int;

        var aMin = 0;
        var aMax = nVals-1;

        // fill a with random ints from a range
        fillRandInt(a, aMin, aMax+1);

        const bDom = newBlockDom({0..#m});
        var b: [bDom] int;
        var expected: real;

        if (m < nVals) {
            [(i, bi) in zip(bDom, b)] bi = i * (nVals / m);
            expected = n:real * (m:real / nVals:real);
        }
        else {
            [(i, bi) in zip(bDom, b)] bi = i % nVals;
            expected = n:real;
        }

        writeln(">>> in1dAr2PerLocAssoc");
        var t1 = Time.getCurrentTime();
        // returns a boolean vector
        var truth = in1dAr2PerLocAssoc(a, b);
        writeln("total time = ", Time.getCurrentTime() - t1, "sec"); try! stdout.flush();
        writeln("<<< #a[i] in b = ", + reduce truth, " (expected ", expected, ")");try! stdout.flush();

        writeln(">>> in1dSort");
        t1 = Time.getCurrentTime();
        var truth2 = in1dSort(a, b);
        writeln("total time = ", Time.getCurrentTime() - t1, "sec"); try! stdout.flush();
        writeln("<<< #a[i] in b = ", + reduce truth2, " (expected ", expected, ")");try! stdout.flush();

        writeln("Results of both strategies match? >>> ", && reduce (truth == truth2), " <<<");
    }

    proc test_strings(n: int, m: int, minLen: int, maxLen: int, coverage: real, thorough: bool) throws {
        writeln("(n, m, minLen, maxLen)");
        writeln((n, m, minLen, maxLen)); try! stdout.flush();

        var st = new owned SymTab();
        var (str1, str2) = createRandomStrings(n, m, minLen, maxLen, coverage, st);
        var expected: real = coverage*n;

        writeln(">>> in1d");
        var t1 = Time.getCurrentTime();
        // returns a boolean vector
        var truth = in1d(str1, str2);
        writeln("total time = ", Time.getCurrentTime() - t1, "sec"); try! stdout.flush();
        writeln("<<< #str1[i] in str2 = ", + reduce truth, " (expected ", expected, ")");try! stdout.flush();
        if thorough {
          var res: [truth.domain] bool;
          forall i in 0..#str1.size {
            const s = str1[i];
            for j in 0..#str2.size {
              if (s == str2[j]) {
                res[i] = true;
                break;
              }
            }
          }
          writeln("Long check passed? >>> ", && reduce (truth == res), " <<<");
        }
    }

    config const N = 10_000;
    config const M = 1_000;
    config const NVALS = 10_000;
    config const testStrings = true;
    config const MINLEN = 0;
    config const MAXLEN = 10;
    config const COVERAGE = 0.5;
    config const longCheck = false;

    proc main() {
        test_in1d(N, M, NVALS);
        if testStrings {
          try! test_strings(N, M, MINLEN, MAXLEN, COVERAGE, longCheck);
        }
    }
    
}
