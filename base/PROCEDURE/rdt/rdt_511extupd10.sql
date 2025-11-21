SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_511ExtUpd10                                     */
/* Purpose: Trigger receiving out interface                             */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2022-06-07 1.0  James      WMS-19824. Created                        */
/************************************************************************/

CREATE PROC [RDT].[rdt_511ExtUpd10] (
   @nMobile        INT,
   @nFunc          INT,
   @cLangCode      NVARCHAR( 3),
   @nStep          INT,
   @nInputKey      INT,
   @cFacility      NVARCHAR( 5),
   @cStorerKey     NVARCHAR( 15),
   @cFromID        NVARCHAR( 18),
   @cFromLOC       NVARCHAR( 10),
   @cToLOC         NVARCHAR( 10),
   @nErrNo         INT           OUTPUT,
   @cErrMsg        NVARCHAR( 20) OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF

   DECLARE @cTransmitLogKey   NVARCHAR( 10) = ''
   DECLARE @bSuccess          INT = 0
   DECLARE @cLocationType     NVARCHAR( 10)
   DECLARE @cLocationCategory NVARCHAR( 10)
   DECLARE @cCommand          NVARCHAR( MAX)

    DECLARE @c_APP_DB_Name         NVARCHAR(20)=''      
           ,@c_DataStream          VARCHAR(10)=''      
           ,@n_ThreadPerAcct       INT=0      
           ,@n_ThreadPerStream     INT=0      
           ,@n_MilisecondDelay     INT=0      
           ,@c_IP                  NVARCHAR(20)=''      
           ,@c_PORT                NVARCHAR(5)=''      
           ,@c_IniFilePath         NVARCHAR(200)=''      
           ,@c_CmdType             NVARCHAR(10)=''      
           ,@c_TaskType            NVARCHAR(1)=''    
           ,@n_ShipCounter         INT = 0           
           ,@n_Priority            INT = 0 
           
   IF @nFunc = 511 -- Move by ID
   BEGIN
      IF @nStep = 3 -- ToLOC
      BEGIN
         SELECT @cLocationType = LocationType
         FROM dbo.LOC WITH (NOLOCK)   
         WHERE Loc = @cToLOC   
         AND   Facility = @cFacility  
         
         IF EXISTS ( SELECT 1 FROM dbo.CODELKUP WITH (NOLOCK)   
                     WHERE LISTNAME = 'AGVSTG'  
                     AND   Code = @cLocationType  
                     AND   Storerkey = @cStorerKey)
         BEGIN
            SELECT @c_APP_DB_Name = APP_DB_Name
               , @c_DataStream = DataStream
               , @n_ThreadPerAcct = ThreadPerAcct
               , @n_ThreadPerStream = ThreadPerStream
               , @n_MilisecondDelay = MilisecondDelay
               , @c_IP = IP
               , @c_PORT = PORT
               , @c_IniFilePath = IniFilePath
               , @c_CmdType = CmdType
               , @c_TaskType = TaskType
               , @n_Priority = ISNULL([Priority],0) 
            FROM QCmd_TransmitlogConfig WITH (NOLOCK)
            WHERE TableName = 'ASSIGNTRACKNO'
            AND [App_Name] = 'WMS'
            AND StorerKey = 'ALL'

            SET @nErrNo = 0
            SET @cCommand = N'EXEC [CNDTSITF].[dbo].[isp6412P_WOL_Kontoor_CN_REC_Export] ' +
               N' @c_DataStream = ''6412'' ' +
               N' , @c_StorerKey = ''' + @cStorerKey + '''' +
               N' , @b_Debug = 0 '+
               N' , @b_Success = 0 '+
               N' , @n_Err = 0 '+
               N' , @c_ErrMsg = ''''' +
               N' , @c_LLI_ID = ''' + @cFromID + ''''

            EXEC isp_QCmd_SubmitTaskToQCommander
               @cTaskType = 'O' -- D=By Datastream, T=Transmitlog, O=Others
               , @cStorerKey = @cStorerKey
               , @cDataStream = '6412'
               , @cCmdType = 'SQL'
               , @cCommand = @cCommand
               , @cTransmitlogKey = @cTransmitLogKey
               , @nThreadPerAcct = @n_ThreadPerAcct
               , @nThreadPerStream = @n_ThreadPerStream
               , @nMilisecondDelay = @n_MilisecondDelay
               , @nSeq = 1
               , @cIP = @c_IP
               , @cPORT = @c_PORT
               , @cIniFilePath = @c_IniFilePath
               , @cAPPDBName = @c_APP_DB_Name
               , @bSuccess = 1
               , @nErr = 0
               , @cErrMsg = ''
               , @nPriority = @n_Priority
                  
            IF @nErrNo <> 0
               GOTO Quit
         END
      END
   END

Quit:

END

GO