import os
import sqlite3
import json
import sys
import argparse

# Try to import readline for command history (up/down arrows)
try:
    import readline
    HAS_READLINE = True
except ImportError:
    HAS_READLINE = False

# Define paths relative to this script so the tool works after CMake copies it.
WORKSPACE_ROOT = os.path.dirname(os.path.abspath(__file__))
SQL_DIR = os.path.join(WORKSPACE_ROOT, "sql")
MAIN_SQL = os.path.join(SQL_DIR, "main.sql")
DB_FILE = os.path.join(WORKSPACE_ROOT, "device_network.db")
JSON_FILE = os.path.join(WORKSPACE_ROOT, "database_paths.json")

def get_sql_files():
    """Automatically discover and sort numbered SQL files in SQL_DIR."""
    import re
    try:
        if not os.path.exists(SQL_DIR):
            print(f"Warning: SQL directory {SQL_DIR} does not exist.")
            return []
        
        # Find all files matching pattern: NN_*.sql (where NN is two digits)
        files = []
        for filename in os.listdir(SQL_DIR):
            if re.match(r'^\d{2}_.*\.sql$', filename):
                files.append(filename)
        
        # Sort by the number prefix (01_, 02_, etc.)
        files.sort()
        
        # Convert to full paths
        sql_files = [os.path.join(SQL_DIR, f) for f in files]
        return sql_files
    except Exception as e:
        print(f"Error discovering SQL files: {e}")
        return []

# Dynamically get SQL files on startup
SQL_FILES = get_sql_files()

def merge_sql_files():
    """Merge the numbered SQL files into main.sql."""
    try:
        with open(MAIN_SQL, 'w', encoding='utf-8') as outfile:
            for sql_file in SQL_FILES:
                if os.path.exists(sql_file):
                    with open(sql_file, 'r', encoding='utf-8') as infile:
                        outfile.write(infile.read() + '\n')
                else:
                    print(f"Warning: {sql_file} not found, skipping.")
        print(f"SQL files merged into {MAIN_SQL}")
    except Exception as e:
        print(f"Error merging SQL files: {e}")

def create_db():
    """Execute main.sql to create/update the SQLite database."""
    return create_db_from_sql(MAIN_SQL, DB_FILE)

def create_db_from_sql(sql_file=MAIN_SQL, db_file=DB_FILE):
    """Execute a SQL file to create/update the SQLite database."""
    try:
        if not os.path.exists(sql_file):
            print(f"Error: {sql_file} does not exist.")
            return False
        db_dir = os.path.dirname(os.path.abspath(db_file))
        if db_dir:
            os.makedirs(db_dir, exist_ok=True)
        conn = sqlite3.connect(db_file)
        conn.execute("PRAGMA foreign_keys = ON;")
        with open(sql_file, 'r', encoding='utf-8') as f:
            sql_script = f.read()
        conn.executescript(sql_script)
        conn.commit()
        conn.close()
        print(f"Database created/updated at {db_file}")
        return True
    except Exception as e:
        print(f"Error creating database: {e}")
        return False

def save_paths():
    """Save the paths of main.sql and device_network.db to a JSON file."""
    try:
        data = {
            "main_sql": os.path.abspath(MAIN_SQL),
            "device_network_db": os.path.abspath(DB_FILE)
        }
        with open(JSON_FILE, 'w', encoding='utf-8') as f:
            json.dump(data, f, indent=4)
        print(f"Paths saved to {JSON_FILE}")
    except Exception as e:
        print(f"Error saving paths: {e}")

def show_all_paths():
    """Display all paths used in the application."""
    print("\n" + "="*50)
    print("WORKSPACE PATHS")
    print("="*50)
    print(f"Workspace Root: {WORKSPACE_ROOT}")
    print(f"SQL Directory:  {SQL_DIR}")
    print(f"Main SQL File:  {MAIN_SQL}")
    print(f"Database File:  {DB_FILE}")
    print(f"JSON File:      {JSON_FILE}")
    print("="*50 + "\n")

def show_json_content():
    """Display the content of the JSON file containing paths."""
    if not os.path.exists(JSON_FILE):
        print(f"\nWarning: {JSON_FILE} does not exist. Run 'cre database' first.\n")
        return
    try:
        with open(JSON_FILE, 'r', encoding='utf-8') as f:
            data = json.load(f)
        print("\n" + "="*50)
        print("JSON PATHS CONTENT")
        print("="*50)
        for key, value in data.items():
            print(f"{key}: {value}")
        print("="*50 + "\n")
    except Exception as e:
        print(f"\nError reading JSON file: {e}\n")

def show_sql_files():
    """Display discovered SQL files that will be merged."""
    print("\n" + "="*50)
    print("DISCOVERED SQL FILES")
    print("="*50)
    if not SQL_FILES:
        print("No SQL files found!")
    else:
        print(f"Total: {len(SQL_FILES)} file(s)\n")
        for i, sql_file in enumerate(SQL_FILES, 1):
            exists = "OK" if os.path.exists(sql_file) else "MISSING"
            filename = os.path.basename(sql_file)
            print(f"{i}. [{exists}] {filename}")
    print("="*50 + "\n")

def normalize_device_type(os_name):
    """Convert the devices.os value to a Netmiko device_type."""
    if not os_name:
        return "cisco_ios"

    normalized = os_name.strip().lower().replace("-", "_").replace(" ", "_")
    aliases = {
        "ios": "cisco_ios",
        "cisco_ios": "cisco_ios",
        "ios_xe": "cisco_xe",
        "cisco_xe": "cisco_xe",
        "nxos": "cisco_nxos",
        "cisco_nxos": "cisco_nxos",
        "asa": "cisco_asa",
        "cisco_asa": "cisco_asa",
    }
    return aliases.get(normalized, normalized)

def get_device_from_db(host):
    """Load login details for a host from the devices table."""
    if not os.path.exists(DB_FILE):
        print(f"\n[ERROR] Database file not found: {DB_FILE}")
        print("        Run 'cre database' or '--init-db' first.\n")
        return None

    try:
        conn = sqlite3.connect(DB_FILE)
        conn.row_factory = sqlite3.Row
        row = conn.execute(
            """
            SELECT host, method, portnumber, username, password, os
            FROM devices
            WHERE host = ?
            """,
            (host,),
        ).fetchone()
        conn.close()
    except sqlite3.Error as e:
        print(f"\n[ERROR] Could not read devices table: {e}\n")
        return None

    if row is None:
        print(f"\n[ERROR] Device '{host}' was not found in devices table.")
        print("        Add it to device_network.db or use:")
        print("        login <host> <method> <port> <user> <pass>\n")
        return None

    method = (row["method"] or "ssh").strip().lower()
    port = row["portnumber"] or (23 if method == "telnet" else 22)
    return {
        "host": row["host"],
        "method": method,
        "port": port,
        "username": row["username"] or "",
        "password": row["password"] or "",
        "device_type": normalize_device_type(row["os"]),
    }

def handle_login(args):
    """Handle login commands using direct arguments or devices table rows."""
    if len(args) == 1:
        device = get_device_from_db(args[0])
        if device is None:
            return
        start_config_mode = True
        db_path = DB_FILE
    elif len(args) == 2 and args[0].lower() == "db":
        device = get_device_from_db(args[1])
        if device is None:
            return
        start_config_mode = True
        db_path = DB_FILE
    elif len(args) >= 5:
        device = {
            "host": args[0],
            "method": args[1],
            "port": args[2],
            "username": args[3],
            "password": args[4],
            "device_type": "cisco_ios",
        }
        start_config_mode = False
        db_path = None
    else:
        print("\n[ERROR] Invalid login command format")
        print("    Usage: login <host>                         # load from devices table")
        print("    Usage: login db <host>                      # load from devices table")
        print("    Usage: login <host> <method> <port> <user> <pass>")
        print("    Example: login 192.168.1.1")
        print("    Example: login 192.168.1.1 ssh 22 admin cisco123\n")
        return

    # Import lazily so database bootstrap can run without Netmiko installed.
    from login.device_connector import login_device

    login_device(
        device["host"],
        device["method"],
        device["port"],
        device["username"],
        device["password"],
        device_type=device["device_type"],
        start_config_mode=start_config_mode,
        db_path=db_path,
    )

def run_non_interactive(argv):
    """Run non-interactive commands used by the Qt frontend."""
    parser = argparse.ArgumentParser(description="NetworkTools Python app kernel")
    parser.add_argument("--init-db", action="store_true", help="Create/update a SQLite database from SQL")
    parser.add_argument("--sql", default=MAIN_SQL, help="Path to main.sql")
    parser.add_argument("--db", default=DB_FILE, help="Path to device_network.db")
    args = parser.parse_args(argv)

    if args.init_db:
        ok = create_db_from_sql(args.sql, args.db)
        if ok:
            save_paths_for(args.sql, args.db)
            return 0
        return 1

    parser.print_help()
    return 1

def save_paths_for(main_sql, device_network_db):
    """Save explicit paths of main.sql and device_network.db to JSON."""
    try:
        data = {
            "main_sql": os.path.abspath(main_sql),
            "device_network_db": os.path.abspath(device_network_db)
        }
        with open(JSON_FILE, 'w', encoding='utf-8') as f:
            json.dump(data, f, indent=4)
        print(f"Paths saved to {JSON_FILE}")
    except Exception as e:
        print(f"Error saving paths: {e}")

def get_input_with_history(prompt):
    """Get user input with history support if readline is available."""
    if HAS_READLINE:
        try:
            return input(prompt).strip()
        except EOFError:
            return "exit"
    else:
        return input(prompt).strip()

def main():
    """Main CLI loop."""
    print("\n" + "="*60)
    print(" NETWORK DATABASE MANAGER")
    print("="*60)
    print("\n[Commands]:")
    print("  - cre database    - Create/merge SQL files and build database")
    print("  - find database   - Find and update database")
    print("  - login <host>    - Login using device_network.db devices table")
    print("  - login db <host> - Login using device_network.db devices table")
    print("  - login <h> <m> <p> <u> <pass> - Login to device (h=host, m=method, p=port, u=user)")
    print("  - info paths      - Show all system paths")
    print("  - info json       - Show JSON file content")
    print("  - info sql        - Show discovered SQL files")
    print("  - exit            - Exit application")
    if HAS_READLINE:
        print("\n[Tip]: Use up/down arrow keys for command history")
    else:
        print("\n[!] Note: Command history (up/down arrows) not available.")
        print("    To enable: pip install pyreadline (on Windows)")
    print("\n" + "="*60 + "\n")
    while True:
        try:
            cmd = get_input_with_history(">> ")
            if HAS_READLINE:
                readline.add_history(cmd)  # Add to history for arrow keys
            
            # Parse command and arguments
            parts = cmd.split()
            if not parts:
                continue
            
            command = parts[0].lower()
            args = parts[1:] if len(parts) > 1 else []
            
            if command == "cre" and len(parts) > 1 and parts[1].lower() == "database":
                merge_sql_files()
                create_db()
                save_paths()
            elif command == "find" and len(parts) > 1 and parts[1].lower() == "database":
                create_db()
                save_paths()
            elif command == "login":
                handle_login(args)
            elif command == "info" and len(parts) > 1:
                subcommand = parts[1].lower()
                if subcommand == "paths":
                    show_all_paths()
                elif subcommand == "json":
                    show_json_content()
                elif subcommand == "sql":
                    show_sql_files()
                else:
                    print(f"[ERROR] Unknown info subcommand: {subcommand}")
            elif command == "exit":
                print("[*] Exiting...")
                break
            else:
                print("[ERROR] Unknown command. Type 'help' or see menu above.")
        except KeyboardInterrupt:
            print("\nExiting...")
            break
        except Exception as e:
            print(f"Unexpected error: {e}")

if __name__ == "__main__":
    if len(sys.argv) > 1:
        sys.exit(run_non_interactive(sys.argv[1:]))
    main()
