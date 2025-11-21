CREATE TABLE [dbo].[wms_process]
(
    [CurrentTime] datetime NULL,
    [spid] smallint NOT NULL,
    [kpid] smallint NOT NULL,
    [blocked] smallint NOT NULL,
    [waittype] binary(2) NOT NULL,
    [waittime] int NOT NULL,
    [lastwaittype] nchar(32) NOT NULL,
    [waitresource] nchar(256) NOT NULL,
    [dbid] smallint NOT NULL,
    [uid] smallint NOT NULL,
    [cpu] int NOT NULL,
    [physical_io] bigint NOT NULL,
    [memusage] int NOT NULL,
    [login_time] datetime NOT NULL,
    [last_batch] datetime NOT NULL,
    [ecid] smallint NOT NULL,
    [open_tran] smallint NOT NULL,
    [status] nchar(30) NOT NULL,
    [sid] binary(86) NOT NULL,
    [hostname] nchar(128) NOT NULL,
    [program_name] nchar(128) NOT NULL,
    [hostprocess] nchar(8) NOT NULL,
    [cmd] nchar(16) NOT NULL,
    [nt_domain] nchar(128) NOT NULL,
    [nt_username] nchar(128) NOT NULL,
    [net_address] nchar(12) NOT NULL,
    [net_library] nchar(12) NOT NULL,
    [loginame] nchar(128) NOT NULL,
    [context_info] binary(128) NOT NULL,
    [sql_handle] binary(20) NOT NULL,
    [stmt_start] int NOT NULL,
    [stmt_end] int NOT NULL
);
GO

CREATE INDEX [clus_time_spid] ON [dbo].[wms_process] ([CurrentTime], [spid]);
GO