SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* SP: isp_GenericWebServiceHost                                        */  
/* Creation Date: 06 Jun 2012                                           */  
/* Copyright: IDS                                                       */  
/* Written by: Chee Jun Yan                                             */  
/*                                                                      */  
/* Purpose:                                                             */ 
/* Usage:                                                               */  
/*                                                                      */  
/* Called By:                                                           */  
/*                                                                      */  
/* PVCS Version: 1.3                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author   Ver      Purposes                              */  
/* 15-Jul-2013  Chee     1.1      Add StorerKey field to Insert         */
/*                                DTSITF.dbo.WebService_Log (Chee01)    */ 
/* 14-Aug-2013  Chee     1.2      Update responseString instead of      */
/*                                inserting a new row                   */
/*                                Remove BatchNo retrieval (Chee02)     */
/* 25-Oct-2013  Chee     1.3      Remove Hardcoding of Database Name    */
/*                                (Chee03)                              */ 
/* 03-Dec-2014  Ung      1.4      Remove temp table to prevent recompile*/
/************************************************************************/  

CREATE PROC [dbo].[isp_GenericWebServiceHost](  
    @c_RequestMessageName  NVARCHAR(30)  
   ,@c_RequestContent      NVARCHAR(MAX)  
   ,@c_ResponseMessageName NVARCHAR(30)    OUTPUT
   ,@c_ResponseContent     NVARCHAR(MAX)   OUTPUT   
   ,@b_Success             INT             OUTPUT  
   ,@n_Err                 INT             OUTPUT  
   ,@c_ErrMsg              NVARCHAR(250)   OUTPUT  
)  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET ANSI_DEFAULTS OFF  
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE  
      @c_Encoding           NVARCHAR(30), 
      @c_BatchNo            NVARCHAR(10),  
      @c_SprocName          NVARCHAR(50),
      @x_RequestString      XML,
      @x_ResponseString     XML,
      @c_RequestString      NVARCHAR(MAX) ,
      @c_ResponseString     NVARCHAR(MAX) ,
      @c_vbErrMsg           NVARCHAR(MAX) ,
      @d_TimeIn             DATETIME,  
      @d_TimeOut            DATETIME,  
      @n_TotalTime          INT,
      @c_Status             NCHAR(1),
      @c_StorerKey          NVARCHAR(15),   -- Chee01
      @n_SeqNo              INT             -- Chee02

   DECLARE
      @c_ExecStatements      NVARCHAR(4000) ,
      @c_ExecArguments       NVARCHAR(4000) ,
      @n_Err_Out             INT ,        
      @c_ErrMsg_Out          NVARCHAR(250),
      @c_WebServiceLogDBName NVARCHAR(30)   -- Chee03   

   -- DEFAULT
   SET @b_Success = 1
   SET @n_Err = 0
   SET @c_Encoding = 'utf-8'
   SET @c_Status = '9'
   SET @c_BatchNo = ''   -- Chee02

   -- Create XML RequestString
   SET @x_RequestString =  
   (  
      SELECT  
         @c_RequestMessageName          "MessageName",  
         CAST(@c_RequestContent AS XML) "Content"
      FOR XML PATH(''),  
      ROOT('GenericWSRequest')  
   )  

   SET @c_RequestString = CAST(@x_RequestString AS NVARCHAR(MAX))

   -- (Chee03)
   SELECT @c_WebServiceLogDBName = NSQLValue  
   FROM dbo.NSQLConfig WITH (NOLOCK)  
   WHERE ConfigKey = 'WebServiceLogDBName' 

   IF ISNULL(@c_WebServiceLogDBName, '') = ''
   BEGIN
      SET @b_Success = 0  
      SET @n_Err = 10000
      SET @c_ErrMsg = 'NSQL' + CONVERT(NCHAR(5),ISNULL(@n_Err,0)) +  
                      ': NSQLConfig - WebServiceLogDBName is empty. (isp_GenericWebServiceHost)'  
      GOTO Quit 
   END

   SET @d_TimeIn = GETDATE()

   SET @c_ExecStatements = ''  
   SET @c_ExecArguments = ''   
   SET @c_ExecStatements = N'INSERT INTO ' + ISNULL(RTRIM(@c_WebServiceLogDBName),'') + '.dbo.WebService_Log ( '  
                          + 'DataStream, StorerKey, Type, BatchNo, WebRequestURL, WebRequestMethod, ContentType, '
                          + 'RequestString, TimeIn, Status, ClientHost, WSIndicator, SourceKey, SourceType) '   
                          + 'VALUES ( @cDataStream, @cStorerKey, @cType, @cBatchNo, @cWebRequestURL, @cWebRequestMethod, @cContentType, '
                          + '@cRequestString, @d_TimeIn, @cStatus, @cClientHost, @cWSIndicator, @cSourceKey, @cSourceType) ' + CHAR(13)
                          + 'SET @n_SeqNo = @@IDENTITY '
                          
   SET @c_ExecArguments = N'@cDataStream       NVARCHAR(10), ' 
                         + '@cStorerKey        NVARCHAR(15), '
                         + '@cType             NVARCHAR(1), '
                         + '@cBatchNo          NVARCHAR(10), '
                         + '@cWebRequestURL    NVARCHAR(1000), '
                         + '@cWebRequestMethod NVARCHAR(10), '
                         + '@cContentType      NVARCHAR(100), '
                         + '@cRequestString    NVARCHAR(MAX), '
                         + '@d_TimeIn          DATETIME, '
                         + '@cStatus           NVARCHAR(1), '
                         + '@cClientHost       NVARCHAR(1), '
                         + '@cWSIndicator      NVARCHAR(1), '
                         + '@cSourceKey        NVARCHAR(50), '
                         + '@cSourceType       NVARCHAR(50), '
                         + '@n_SeqNo           INT  OUTPUT'  
                         
   EXEC sp_ExecuteSql @c_ExecStatements, @c_ExecArguments, 
                      '', '', 'I', @c_BatchNo, '', '', '',
                      @c_RequestString, @d_TimeIn, @c_Status, 'H', 'R', @c_RequestMessageName, 'isp_GenericWebServiceHost', @n_SeqNo OUTPUT 

   IF @@ERROR <> 0  
   BEGIN  
      SET @b_Success = 0  
      SET @n_Err = 10001  
      SET @c_ErrMsg = 'NSQL' + CONVERT(NCHAR(5),ISNULL(@n_Err,0)) +  
                      ': Error inserting into WebService_Log Table. (isp_GenericWebServiceHost)'  
      GOTO Quit  
   END  

   -- Select SprocName and ResponseMessageName based on RequestMessageName
   SELECT 
      @c_SprocName = SprocName,
      @c_ResponseMessageName = ResponseMessageName,
      @c_StorerKey = ISNULL(RTRIM(StorerKey), '') -- Chee01
   FROM [GenericWebServiceHost_Process] WITH (NOLOCK)
   WHERE RequestMessageName = @c_RequestMessageName

   -- (Chee03)
--   -- Update StorerKey to WebService_Log (Chee01)

   SET @c_ExecStatements = ''  
   SET @c_ExecArguments = ''   
   SET @c_ExecStatements = N'UPDATE ' + ISNULL(RTRIM(@c_WebServiceLogDBName),'') + '.dbo.WebService_Log WITH (ROWLOCK) '  
                          + 'SET StorerKey = @c_StorerKey '
                          + 'WHERE SeqNo = @n_SeqNo'
        
   SET @c_ExecArguments = N'@c_StorerKey  NVARCHAR(15), '
                         + '@n_SeqNo      INT'

   EXEC sp_ExecuteSql @c_ExecStatements, @c_ExecArguments, 
                      @c_StorerKey, @n_SeqNo 

   IF @@ERROR <> 0  
   BEGIN  
      SET @b_Success = 0  
      SET @n_Err = 10002  
      SET @c_ErrMsg = 'NSQL' + CONVERT(NCHAR(5),ISNULL(@n_Err,0)) +  
                      ': Error updating WebService_Log Table. (isp_GenericWebServiceHost)'  
      GOTO Quit  
   END  
    
   IF ISNULL(@c_SprocName,'') = ''  
   BEGIN  
      SET @b_Success = 0  
      SET @n_Err = 10003 
      SET @c_ErrMsg = 'NSQL' + CONVERT(NCHAR(5),ISNULL(@n_Err,0)) +  
                      ': Stored Procedure Name is empty. (isp_GenericWebServiceHost)'  
      GOTO Quit  
   END  

   IF ISNULL(@c_ResponseMessageName,'') = ''  
   BEGIN  
      SET @b_Success = 0  
      SET @n_Err = 10004
      SET @c_ErrMsg = 'NSQL' + CONVERT(NCHAR(5),ISNULL(@n_Err,0)) +  
                      ': Response Message Name is empty. (isp_GenericWebServiceHost)'  
      GOTO Quit  
   END  

   -- Exec SP to get Response String
   SET @c_ExecStatements = N'EXEC ' + @c_SprocName + ' '
                          + '@n_SeqNo, '                   -- Chee02
                          + '@c_StorerKey, '               -- Chee01
                          + '@c_RequestString, '    
                          + '@c_ResponseString  OUTPUT, '    
                          + '@b_Success         OUTPUT, '    
                          + '@n_Err_Out         OUTPUT, '
                          + '@c_ErrMsg_Out      OUTPUT'
               
   SET @c_ExecArguments = N' @n_SeqNo          INT
                           , @c_StorerKey      NVARCHAR(15)
                           , @c_RequestString  NVARCHAR(MAX)
                           , @c_ResponseString NVARCHAR(MAX)  OUTPUT
                           , @b_Success        INT            OUTPUT
                           , @n_Err_Out        INT            OUTPUT
                           , @c_ErrMsg_Out     NVARCHAR(250)  OUTPUT'
          
   EXEC sp_ExecuteSql  @c_ExecStatements
                     , @c_ExecArguments
                     , @n_SeqNo                  -- Chee02
                     , @c_StorerKey              -- Chee01
                     , @c_RequestContent
                     , @c_ResponseContent OUTPUT
                     , @b_Success         OUTPUT 
                     , @n_Err_Out         OUTPUT 
                     , @c_ErrMsg_Out      OUTPUT 

   IF @@ERROR <> 0 OR @b_Success = 0
   BEGIN
      IF @b_Success = 0
      BEGIN
         SET @n_Err = @n_Err_Out
         SET @c_ErrMsg = @c_ErrMsg_Out
      END
      ELSE
      BEGIN
         SET @b_Success = 0 
         SET @n_Err = 10005      
         SET @c_ErrMsg = 'NSQL' + CONVERT(NCHAR(5),ISNULL(@n_Err,0)) +  
                      ': Failed to execute: ' +@c_SprocName + ' (isp_GenericWebServiceHost)'  
      END
      GOTO Quit
   END

Quit:  

   IF @b_Success = 1
   BEGIN
      SET @c_ErrMsg = 'Success'
   END
   ELSE
   BEGIN
      SET @c_Status = '5'
   END

   -- Create XML Response String
   SET @x_ResponseString =  
   (  
      SELECT  
         @c_ResponseMessageName                              "MessageName",
         RIGHT('00000' + CONVERT(NVARCHAR(10), @n_Err), 5)   "MessageCode",  
         @c_ErrMsg                                           "MessageDescription",
         CAST(@c_ResponseContent AS XML)                     "Content"
      FOR XML PATH(''),  
      ROOT('GenericWSResponse')  
   )  

   SET @c_ResponseString = CAST(@x_ResponseString AS NVARCHAR(MAX))

   SET @d_TimeOut = GETDATE()
   SET @n_TotalTime = DATEDIFF(ms, @d_TimeIn, @d_TimeOut)  

   SET @c_ExecStatements = ''  
   SET @c_ExecArguments = ''   
   SET @c_ExecStatements = N'UPDATE ' + ISNULL(RTRIM(@c_WebServiceLogDBName),'') + '.dbo.WebService_Log WITH (ROWLOCK) '  
                          + 'SET Status = @c_Status, ErrMsg = @c_ErrMsg, '
                          + '    ResponseString = @c_ResponseString, TimeOut = @d_TimeOut, TotalTime = @n_TotalTime '
                          + 'WHERE SeqNo = @n_SeqNo'
        
   SET @c_ExecArguments = N'@c_Status         NVARCHAR(15), '
                         + '@c_ErrMsg         NVARCHAR(215), '
                         + '@c_ResponseString NVARCHAR(MAX), '
                         + '@d_TimeOut        DATETIME, '
                         + '@n_TotalTime      INT, '
                         + '@n_SeqNo          INT'

   EXEC sp_ExecuteSql @c_ExecStatements, @c_ExecArguments, 
                      @c_Status, @c_ErrMsg, @c_ResponseString, @d_TimeOut, @n_TotalTime, @n_SeqNo

   IF @@ERROR <> 0
   BEGIN
      SET @b_Success = 0
      SET @n_Err = 10006
      SET @c_ErrMsg = 'NSQL' + CONVERT(NCHAR(5),ISNULL(@n_Err,0)) +  
                      ': Error updating WebService_Log Table. (isp_GenericWebServiceHost)' 
   END

   -- (Chee03)
   IF OBJECT_ID('tempdb..#StoreSeqNoTempTable','u') IS NOT NULL
      DROP TABLE #StoreSeqNoTempTable;

END -- Procedure

GO