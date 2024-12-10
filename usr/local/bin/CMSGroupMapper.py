
import os
import re
import time
import json

g_expire_time = 0
g_cache = {}
g_site_cache = {}

# Set to false to consider 'local' as a valid sitename.
# Useful mostly for testing purposes.
g_ignore_local = True

def cache_users():
    global g_cache

    base_dir = '/cvmfs/cms.cern.ch/SITECONF'
    cache = {}
    user_re = re.compile(r'[-_A-Za-z0-9.]+')
    sites = None
    try:
        if os.path.isdir(base_dir):
            sites = os.listdir(base_dir)
    except:
        pass
    if not sites:
        return
    for entry in sites:
        full_path = os.path.join(base_dir, entry, 'GlideinConfig', 'local-users.txt')
        if g_ignore_local and (entry == 'local'):
            continue
        if not os.path.isfile(full_path):
            continue
        try:
            fd = open(full_path)
            for line in fd:
                line = line.strip()
                if user_re.match(line):
                    group_set = cache.setdefault(line, set())
                    group_set.add(entry)
        except:
            pass
    for key, val in cache.items():
        cache[key] = (",".join(val), val)

    g_cache = cache


def cache_sites():
    global g_site_cache

    base_dir = '/cvmfs/cms.cern.ch/SITECONF'
    cache = {}
    user_re = re.compile(r'[-_A-Za-z0-9.]+')
    sites = None
    try:
        if os.path.isdir(base_dir):
            sites = os.listdir(base_dir)
    except:
        pass
    if not sites:
        g_expire_time = time.time() + 60
        return
    for entry in sites:
        full_path = os.path.join(base_dir, entry, 'GlideinConfig', 'local-groups.txt')
        if g_ignore_local and (entry == 'local'):
            continue
        if not os.path.isfile(full_path):
            continue
        try:
            valid_group_re = re.compile(r"[-/_A-Za-z0-9]+")
            if os.path.exists(full_path):
                for line in open(full_path).xreadlines():
                    line = line.strip()
                    if valid_group_re.match(line):
                        groups = cache.setdefault(entry, set())
                        groups.add(line)
        except:
            pass
    for key, val in cache.items():
        cache[key] = (",".join(val), val)

    g_site_cache = cache


def check_caches():
    global g_expire_time
    if time.time() > g_expire_time:
        cache_users()
        cache_sites()
        g_expire_time = time.time() + 15*3600


def map_user_to_groups(user):
    check_caches()
    return g_cache.setdefault(user, ("", set()))[0]

def _map_user_to_groups(user):
    check_caches()
    return g_cache.setdefault(user, ("", set()))[1]

def is_local_user(user, site):
    check_caches()
    user_groups = g_cache.setdefault(user, ("", set()))[1]
    site_groups = g_site_cache.setdefault(site, ("", set()))[1]
    return bool(user_groups.intersection(site_groups))


g_split_re = re.compile(r"\s*,\s*")
def is_local_group(groups, site):
    check_caches()
    groups = g_split_re.split(groups)
    groups = set([i for i in groups if i])
    site_groups = g_site_cache.setdefault(site, ("", set()))[1]
    return bool(groups.intersection(site_groups))

def getAllUserGroups(proxyfqan):
    """
    Get all the attributes for the user using getAttributeFromProxy
    and strip the ROLE and CAPABILITIES part.
    Return a generator of things like '/cms/integration', '/cms'
    """
    for attribute in proxyfqan:
        splAttr = attribute.split('/') #splitted attribut
        filtAttr = [part for part in splAttr if not (part.startswith('Role=') or part.startswith('Capability='))] #filtered attribute
        yield '/'.join(filtAttr)

def dnUserName(dn, people):
    """
    Convert DN to Hypernews name. Clear cache between trys
    in case user just registered or fixed an issue with SiteDB
    """
    try:
        userinfo = filter(lambda x: x['dn'] == dn, people)
        username = next(userinfo)['username']
    except (KeyError, IndexError):
        userinfo = filter(lambda x: x['dn'] == dn, people)
        username = next(userinfo)['username']
    return username

def _getCMSGroups(username, proxyfqan):
    """
    - Add all groups associated with the user proxy certificate
    - Add all Sites this user is local to (from local-users.txt in each
      SITECONF)
    """
    mygroups = set.union(_map_user_to_groups(username), getAllUserGroups(proxyfqan))
    cmsgroups = ",".join(i for i in mygroups)
    return cmsgroups


def getCMSGroups(dn, proxyfqan):
    """
    - Add all groups associated with the user proxy certificate
    - Add all Sites this user is local to (from local-users.txt in each
      SITECONF)
    """
    try:
        json_people = json.load(open('/etc/ciconnect/people.list'))
    except IOError:
        return

    username = dnUserName(dn, json_people)
    return _getCMSGroups(username, proxyfqan)

if __name__ == '__main__':
    print(map_user_to_groups("bbockelm"))
    print(is_local_user("bbockelm", "T2_US_Nebraska"))
    print(is_local_group("HIG", "T2_US_Nebraska"))
    print(is_local_group("T2_US_Nebraska", "T2_US_Nebraska"))

    #import classad
    #classad.register(map_user_to_groups)
    #print classad.ExprTree('map_user_to_groups("bbockelm")').eval()
