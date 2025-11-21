SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Function: fnc_GetArchiveDB                                           */
/* Creation Date: 01-FEB-2017                                           */
/* Copyright: LF Logistics                                              */
/* Written by: YTWan                                                    */
/*                                                                      */
/* Purpose:                                                             */
/*        :                                                             */
/* Called By:                                                           */
/*          :                                                           */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver Purposes                                  */
/************************************************************************/
CREATE FUNCTION [dbo].[fnc_GetArchiveDB] ()
RETURNS NVARCHAR(MAX) AS
BEGIN
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF

   DECLARE @c_ArchiveLinkServer  NVARCHAR(30)
          ,@c_ArchiveDBName      NVARCHAR(30)

   SET @c_ArchiveLinkServer = ''
   SET @c_ArchiveDBName     = ''

   SELECT @c_ArchiveLinkServer = ISNULL(RTRIM(NSQLValue),'')
   FROM NSQLCONFIG WITH (NOLOCK) 
   WHERE Configkey = 'ArchiveLinkServer'

   SELECT @c_ArchiveDBName = ISNULL(RTRIM(NSQLValue),'')
   FROM NSQLCONFIG WITH (NOLOCK) 
   WHERE Configkey = 'ArchiveDBName'
   
   IF @c_ArchiveLinkServer <> ''
   BEGIN
      IF RIGHT(@c_ArchiveLinkServer,1) <> '.'
      BEGIN
         SET @c_ArchiveLinkServer = @c_ArchiveLinkServer + '.'
      END
      SET @c_ArchiveDBName = @c_ArchiveLinkServer + @c_ArchiveDBName
   END

   IF RIGHT(@c_ArchiveDBName,1) <> '.'
   BEGIN
      SET @c_ArchiveDBName = @c_ArchiveDBName + '.'
   END

   RETURN @c_ArchiveDBName
END -- procedure

GO