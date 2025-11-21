SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Function:  isp_VFCDC_WCS_CartonTracking                              */
/* Creation Date: 02-Sep-2013                                           */
/* Copyright: IDS                                                       */
/* Written by: Chee Jun Yan                                             */
/*                                                                      */
/* Purpose:  Track messages between WMS and WCS by LPNNo                */
/*                                                                      */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author   Ver.     Purposes                              */
/* 25-Oct-2013  Chee     1.1      Remove Hardcoding of Database Name    */
/*                                (Chee01)                              */
/************************************************************************/

CREATE PROC [dbo].[isp_VFCDC_WCS_CartonTracking] (
   @c_LPNNoFilter   NVARCHAR(20)
)
AS
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET ANSI_NULLS OFF

   DECLARE 
      @n_SeqNo           INT,
      @c_Type            NVARCHAR(1),
      @c_MessageType     NVARCHAR(70),
      @c_Command         NVARCHAR(20),
      @c_ContainerType   NVARCHAR(20),
      @c_LPNNo           NVARCHAR(20),
      @c_Destination     NVARCHAR(20),
      @c_PrintString     NVARCHAR(50),
      @f_Weight          FLOAT,
      @c_User            NVARCHAR(20),
      @d_TimeIn          DATETIME,
      @d_TimeOut         DATETIME,
      @n_TotalTime       INT,
      @c_Status          NVARCHAR(1),
      @c_ErrMsg          NVARCHAR(215),
      @x_RequestString   XML,
      @c_StorerKey       NVARCHAR(15),
      @n_doc             INT,
      @c_XMLNamespace    NVARCHAR(100)

   -- (Chee01)
   DECLARE 
      @c_ExecStatements         NVARCHAR(4000),  
      @c_ExecArguments          NVARCHAR(4000), 
      @c_WebServiceLogDBName    NVARCHAR(30)

   DECLARE @rtnTable TABLE 
   (
      SeqNo         INT,
      [Type]        NVARCHAR(1),
      MessageType   NVARCHAR(70),
      LPNNo         NVARCHAR(20),
      Destination   NVARCHAR(20),
      PrintString   NVARCHAR(50),
      Weight        FLOAT, 
      [User]        NVARCHAR(20),
      TimeIn        DATETIME,
      TimeOut       DATETIME,
      TotalTime     INT,
      Status        NVARCHAR(1),
      ErrorMessage  NVARCHAR(215),
      RequestString XML
   )

   SET @c_StorerKey = '18405'
   SET @c_XMLNamespace = '<root xmlns:p="http://Dematic.com.au/WCSXMLSchema/VF"/>'

   -- (Chee01)
   SELECT @c_WebServiceLogDBName = NSQLValue  
   FROM dbo.NSQLConfig WITH (NOLOCK)  
   WHERE ConfigKey = 'WebServiceLogDBName' 

   IF ISNULL(@c_WebServiceLogDBName, '') = ''
   BEGIN
      --RAISERROR 13000 'NSQLConfig - WebServiceLogDBName is empty.'
      RAISERROR ('NSQLConfig - WebServiceLogDBName is empty.', 16, 1) WITH SETERROR    -- SQL2012
      RETURN 
   END

   SET @c_ExecStatements = ''  
   SET @c_ExecArguments = ''   
   SET @c_ExecStatements = N'DECLARE CUR_CARTON_TRACKING CURSOR FAST_FORWARD READ_ONLY FOR '
                          + 'SELECT SeqNo, SourceKey, [Type], AddWho, TimeIn, TimeOut, TotalTime, Status, ErrMsg, SourceType, '
                          + 'CAST(REPLACE(REPLACE(RequestString, ''<?xml version="1.0" encoding="utf-8"?>'', ''''), ' 
                          + '''<?xml version="1.0" encoding="UCS"?>'', '''') AS XML) '
                          + 'FROM ' + ISNULL(RTRIM(@c_WebServiceLogDBName),'') + '.dbo.WebService_LOG WITH (NOLOCK) '
                          + 'WHERE StorerKey = @c_StorerKey '
                          + '  AND SourceType IN (''isp_WS_WCS_VF_ContainerCommand'', ''isp_WS_WCS_VF_PrintingInfor'', ''Container_StateChange_Sorted'') '
                          + '  AND SourceKey = @c_LPNNoFilter '
                          + 'ORDER BY SeqNo'

   SET @c_ExecArguments = N'@c_LPNNoFilter NVARCHAR(20), ' 
                         + '@c_StorerKey   NVARCHAR(15)'

   EXEC sp_ExecuteSql @c_ExecStatements, @c_ExecArguments, 
                      @c_LPNNoFilter, @c_StorerKey

   OPEN CUR_CARTON_TRACKING
   FETCH NEXT FROM CUR_CARTON_TRACKING INTO @n_SeqNo, @c_LPNNo, @c_Type, @c_User, @d_TimeIn, @d_TimeOut, @n_TotalTime, @c_Status, @c_ErrMsg, @c_MessageType, @x_RequestString 

   WHILE @@FETCH_STATUS <> -1  
   BEGIN  

      EXEC sp_xml_preparedocument @n_doc OUTPUT, @x_RequestString, @c_XMLNamespace

      SET @c_Command = NULL
      SET @c_ContainerType = NULL
      SET @c_Destination = NULL
      SET @c_PrintString = NULL
      SET @f_Weight = NULL

      IF @c_Type = 'O'
      BEGIN
         SELECT @c_MessageType = localName
         FROM OPENXML (@n_doc, '', 2)  
         WHERE ParentID = 0 AND NodeType = 1
      END

      IF @c_MessageType = 'ContainerCommand'
      BEGIN
         SELECT      
            @c_Command       = [Command],
            @c_ContainerType = [ContainerType],
            @c_Destination   = [Destination]
         FROM OPENXML (@n_doc, '/p:Download/ContainerCommand', 2)  
         WITH(  
            [Command]        NVARCHAR(20),
            [ContainerType]  NVARCHAR(20),
            [Destination]    NVARCHAR(50)
         )

         SET @c_MessageType = @c_MessageType + '_' + @c_Command + CASE WHEN ISNULL(@c_ContainerType, '') <> '' THEN '_' + @c_ContainerType ELSE '' END
      END
      ELSE IF @c_MessageType = 'PrintingInfor'
      BEGIN
         SELECT      
            @c_LPNNo       = [ContainerID],
            @c_PrintString = [PrintString]
         FROM OPENXML (@n_doc, '/p:Download/PrintingInfor', 2)  
         WITH(  
            [ContainerID]  NVARCHAR(20),
            [PrintString]  NVARCHAR(50)
         )
      END
      ELSE IF @c_MessageType = 'Container_StateChange_Sorted'
      BEGIN
         SELECT      
            @c_LPNNo  = [ContainerID],
            @f_Weight = [Weight]  
         FROM OPENXML (@n_doc, '/GenericWSRequest/Content/p:Upload/Container_StateChange', 2)  
         WITH(  
            [ContainerID]  NVARCHAR(20),
            [Weight]       FLOAT
         )
      END

      INSERT INTO @rtnTable 
      VALUES (@n_SeqNo, @c_Type, @c_MessageType, @c_LPNNo, @c_Destination, @c_PrintString, @f_Weight, 
              @c_User, @d_TimeIn, @d_TimeOut, @n_TotalTime, @c_Status, @c_ErrMsg, @x_RequestString)

      EXEC sp_xml_removedocument @n_doc

      FETCH NEXT FROM CUR_CARTON_TRACKING INTO @n_SeqNo, @c_LPNNo, @c_Type, @c_User, @d_TimeIn, @d_TimeOut, @n_TotalTime, @c_Status, @c_ErrMsg, @c_MessageType, @x_RequestString
   END  
   CLOSE CUR_CARTON_TRACKING
   DEALLOCATE CUR_CARTON_TRACKING

   SELECT SeqNo, [Type], MessageType, LPNNo, Destination, PrintString, Weight, 
          [User], TimeIn, TimeOut, TotalTime, Status, ErrorMessage, RequestString 
   FROM @rtnTable

END -- Procedure

GO