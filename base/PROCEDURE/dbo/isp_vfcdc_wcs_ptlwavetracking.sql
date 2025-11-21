SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Function:  isp_VFCDC_WCS_PTLWaveTracking                             */
/* Creation Date: 02-Sep-2013                                           */
/* Copyright: IDS                                                       */
/* Written by: Chee Jun Yan                                             */
/*                                                                      */
/* Purpose:  Track messages between WMS and WCS by WaveKey              */
/*                                                                      */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author   Ver.     Purposes                              */
/* 25-Oct-2013   Chee     1.1     Remove Hardcoding of Database Name    */
/*                                (Chee01)                              */
/************************************************************************/

CREATE PROC [dbo].[isp_VFCDC_WCS_PTLWaveTracking] (
   @c_WaveKeyFilter   NVARCHAR(10)
)
AS
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET ANSI_NULLS OFF

   DECLARE 
      @n_SeqNo           INT,
      @c_Type            NVARCHAR(1),
      @c_MessageType     NVARCHAR(50),
      @c_WaveKey         NVARCHAR(10),
      @c_OrderKey        NVARCHAR(10),
      @c_OrderLineNumber NVARCHAR(5),
      @c_LPNNo           NVARCHAR(20),
      @c_SKU             NVARCHAR(20),
      @c_ALTSKU          NVARCHAR(20),
      @n_QtyPlaced       INT,
      @n_QtyShorted      INT,
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
      SeqNo            INT,
      [Type]           NVARCHAR(1),
      MessageType      NVARCHAR(50),
      WaveKey          NVARCHAR(10),
      OrderKey         NVARCHAR(10),
      OrderLineNumber  NVARCHAR(5),
      LPNNo            NVARCHAR(20),
      SKU              NVARCHAR(20),
      UPC              NVARCHAR(20),
      QtyPlaced        INT,
      QtyShorted       INT,
      [User]           NVARCHAR(20),
      TimeIn           DATETIME,
      TimeOut          DATETIME,
      TotalTime        INT,
      Status           NVARCHAR(1),
      ErrorMessage     NVARCHAR(215),
      RequestString    XML
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
   SET @c_ExecStatements = N'DECLARE CUR_PTL_WAVE_TRACKING CURSOR FAST_FORWARD READ_ONLY FOR ' 
                         +  'SELECT SeqNo, [Type], AddWho, TimeIn, TimeOut, TotalTime, Status, ErrMsg, SourceType, CAST(RequestString AS XML) '
                         +  'FROM ' + ISNULL(RTRIM(@c_WebServiceLogDBName),'') + '.dbo.WebService_LOG WITH (NOLOCK) '
                         +  'WHERE StorerKey = @c_StorerKey and SourceType IN (''OrderLineEvent'') '
                         +  '  AND SourceKey IN (SELECT OrderKey FROM WAVEDETAIL WITH (NOLOCK) WHERE WaveKey = @c_WaveKeyFilter) '
                         +  'UNION ALL '
                         +  'SELECT SeqNo, [Type], AddWho, TimeIn, TimeOut, TotalTime, Status, ErrMsg, SourceType, CAST(RequestString AS XML) '
                         +  'FROM ' + ISNULL(RTRIM(@c_WebServiceLogDBName),'') + '.dbo.WebService_LOG WITH (NOLOCK) '
                         +  'WHERE StorerKey = @c_StorerKey and SourceType IN (''Container_StateChange_Closed'') ' 
                         +  '  AND SourceKey IN (SELECT DISTINCT DropID FROM PICKDETAIL WITH (NOLOCK) WHERE OrderKey IN ' 
                         +  '                   (SELECT OrderKey FROM WAVEDETAIL WITH (NOLOCK) WHERE WaveKey = @c_WaveKeyFilter)) ' 
                         +  'UNION ALL '
                         +  'SELECT SeqNo, [Type], AddWho, TimeIn, TimeOut, TotalTime, Status, ErrMsg, SourceType, '
                         +  '     CAST(REPLACE(RequestString, ''<?xml version="1.0" encoding="UCS"?>'', '''') AS XML) ' 
                         +  'FROM ' + ISNULL(RTRIM(@c_WebServiceLogDBName),'') + '.dbo.WebService_LOG WITH (NOLOCK) '
                         +  'WHERE StorerKey = @c_StorerKey and SourceType IN (''ispWAVRL02'', ''Wave_StateChange_Closed'') '
                         +  '  AND SourceKey = @c_WaveKeyFilter '
                         +  'ORDER BY SeqNo'

   SET @c_ExecArguments = N'@c_WaveKeyFilter NVARCHAR(10), ' 
                         + '@c_StorerKey     NVARCHAR(15)'

   EXEC sp_ExecuteSql @c_ExecStatements, @c_ExecArguments, 
                      @c_WaveKeyFilter, @c_StorerKey

   OPEN CUR_PTL_WAVE_TRACKING
   FETCH NEXT FROM CUR_PTL_WAVE_TRACKING INTO @n_SeqNo, @c_Type, @c_User, @d_TimeIn, @d_TimeOut, @n_TotalTime, @c_Status, @c_ErrMsg, @c_MessageType, @x_RequestString 

   WHILE @@FETCH_STATUS <> -1  
   BEGIN  
      SET @c_WaveKey = NULL
      SET @c_OrderKey = NULL
      SET @c_OrderLineNumber = NULL
      SET @c_LPNNo = NULL
      SET @c_SKU = NULL
      SET @c_ALTSKU = NULL
      SET @n_QtyPlaced = NULL
      SET @n_QtyShorted = NULL

      EXEC sp_xml_preparedocument @n_doc OUTPUT, @x_RequestString, @c_XMLNamespace

      IF @c_MessageType = 'OrderLineEvent'
      BEGIN
         SELECT      
            @c_OrderKey        = [WorkAssignmentID],
            @c_OrderLineNumber = SUBSTRING([MissionID], 11, 5),
            @c_ALTSKU          = [SKUID],       
            @n_QtyPlaced       = [QtyPlaced],
            @n_QtyShorted      = [QtyShorted],
            @c_User            = [OperatorID],
            @c_LPNNo           = [ContainerID]
         FROM OPENXML (@n_doc, '/GenericWSRequest/Content/p:Upload/OrderLineEvent', 2)  
         WITH(  
            [WorkAssignmentID]   NVARCHAR(10),
            [SKUID]              NVARCHAR(20),
            [MissionID]          NVARCHAR(20),
            [QtyPlaced]          INT,
            [QtyShorted]         INT,
            [OperatorID]         NVARCHAR(18),
            [ContainerID]        NVARCHAR(20)
         )

         SELECT @c_SKU = SKU 
         FROM SKU WITH (NOLOCK) 
         WHERE ALTSKU = @c_ALTSKU
      END
      ELSE IF @c_MessageType = 'Container_StateChange_Closed'
      BEGIN
         SELECT      
            @c_LPNNo  = [ContainerID]
         FROM OPENXML (@n_doc, '/GenericWSRequest/Content/p:Upload/Container_StateChange', 2)  
         WITH(  
            [ContainerID]   NVARCHAR(20)
         )
      END
      ELSE IF @c_MessageType = 'ispWAVRL02'
      BEGIN
         SELECT      
            @c_WaveKey  = [WaveID]
         FROM OPENXML (@n_doc, '/p:Download/Wave', 2)  
         WITH(  
            [WaveID]   NVARCHAR(10)
         )
      END
      ELSE IF @c_MessageType = 'Wave_StateChange_Closed'
      BEGIN
         SELECT      
            @c_WaveKey  = [WaveID]
         FROM OPENXML (@n_doc, '/GenericWSRequest/Content/p:Upload/Wave_StateChange', 2)  
         WITH(  
            [WaveID]   NVARCHAR(10)
         )
      END

      INSERT INTO @rtnTable 
      VALUES (@n_SeqNo, @c_Type, @c_MessageType, @c_WaveKey, @c_OrderKey, @c_OrderLineNumber, @c_LPNNo, @c_SKU, @c_ALTSKU, @n_QtyPlaced, @n_QtyShorted,
              @c_User, @d_TimeIn, @d_TimeOut, @n_TotalTime, @c_Status, @c_ErrMsg, @x_RequestString)

      EXEC sp_xml_removedocument @n_doc

      FETCH NEXT FROM CUR_PTL_WAVE_TRACKING INTO @n_SeqNo, @c_Type, @c_User, @d_TimeIn, @d_TimeOut, @n_TotalTime, @c_Status, @c_ErrMsg, @c_MessageType, @x_RequestString
   END  
   CLOSE CUR_PTL_WAVE_TRACKING
   DEALLOCATE CUR_PTL_WAVE_TRACKING

   SELECT SeqNo, [Type], MessageType, WaveKey, LPNNo, OrderKey, OrderLineNumber, SKU, UPC, QtyPlaced, QtyShorted, 
          [User], TimeIn, TimeOut, TotalTime, Status, ErrorMessage, RequestString 
   FROM @rtnTable

END -- Procedure

GO