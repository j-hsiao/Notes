import random

def mean(data):
    return sum(data) / len(data)

def variance(data, dof=1):
    tot = sum(data)
    totsq = sum([x**2 for x in data])
    return (totsq - len(data)*(tot/len(data))**2)/(len(data)-dof)


def check_merge(lo, hi):
    C1 = random.randint(lo, hi)
    C2 = random.randint(lo, hi)
    C = C1 + C2
    x1 = [random.uniform(-1,1) for _ in range(C1)]
    x2 = [random.uniform(-1,1) for _ in range(C2)]

    for dof in range(2):
        targetmean = mean(x1 + x2)
        targetvar = variance(x1+x2, dof)

        X1 = mean(x1)
        X2 = mean(x2)
        D1 = C1-dof
        D2 = C2-dof
        V1 = variance(x1, dof)
        V2 = variance(x2, dof)
        D = (C1 + C2)-dof

        resultmean = (X1*C1 + X2*C2) / C
        print('dof:', dof)
        print(f'  meandif: {abs(resultmean - targetmean):.10f}')

        # resultvar = (V1*D1 + V2*D2 + C1*X1*X1 + C2*X2*X2 - C*resultmean*resultmean) / D
        resultvar = (V1*D1 + V2*D2 + (C1*C2/C)*(X1-X2)**2) / D
        print(f'  vardif : {abs(resultvar - targetvar):.10f}')

        DV = V1*D1 + V2*D2 + C1*X1**2 + C2*X2**2 - ((C1*X1 + C2*X2)**2) / (C1+C2)
        V = DV/D
        print(f'  vardif : {abs(V - targetvar):.10f}')


def check_lincomb(lo, hi):
    xi = []
    xij = []
    Ci = []
    Xi = []
    Vi = [None] * lo
    Di = [None] * lo
    for dset in range(lo):
        Ci.append(random.randint(lo, hi))
        xij.append([])
        for i in range(Ci[dset]):
            xij[dset].append(random.randint(lo, hi))
        Xi.append(mean(xij[dset]))
        xi.extend(xij[dset])

    X = mean(xi)
    C = len(xi)
    for dof in range(2):
        V = variance(xi, dof)
        D = C - dof
        for dset in range(lo):
            Vi[dset] = variance(xij[dset], dof)
            Di[dset] = Ci[dset] - dof

        tX = sum([Ci[i]*Xi[i] for i in range(lo)]) / C

        tV = (
            sum([Di[i]*Vi[i] for i in range(lo)])
            + sum([Ci[i]*Xi[i]**2 for i in range(lo)])
            - C*tX**2
        )
        print(f'dof: {dof}')
        print(f'  meandif: {abs(tX - X):.10f}')
        print(f'  vardif : {abs(tV/D - V):.10f}')




if __name__ == '__main__':
    import argparse
    p = argparse.ArgumentParser()
    p.add_argument(
        'count', nargs='*', type=int, help='lo [hi], range of items per dataset',
        default = [100, 200])
    args = p.parse_args()
    if len(args.count) < 2:
        args.count.append(args.count[0])
    print('merge')
    check_merge(*args.count)

    print('linear combination')
    check_lincomb(*args.count)
