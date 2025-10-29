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

if __name__ == '__main__':
    import argparse
    p = argparse.ArgumentParser()
    p.add_argument(
        'count', nargs='*', type=int, help='lo [hi], range of items per dataset',
        default = [10, 20])
    args = p.parse_args()
    if len(args.count) < 2:
        args.count.append(args.count[0])
    check_merge(*args.count)
