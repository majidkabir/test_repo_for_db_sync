SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1812ExtUpd03                                    */
/* Purpose: Extended Update                                             */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date         Author    Ver.  Purposes                                */
/* 2021-09-08   Chermaine 1.0   WMS-17828 Created                       */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdt_1812ExtUpd03]
   @nMobile         INT,          
   @nFunc           INT,          
   @cLangCode       NVARCHAR( 3), 
   @nStep           INT,          
   @nInputKey       INT,          
   @cTaskdetailKey  NVARCHAR( 10),
   @cDropID         NVARCHAR( 20),
   @nQTY            INT,          
   @cToLOC          NVARCHAR( 10),
   @nErrNo          INT OUTPUT,   
   @cErrMsg         NVARCHAR( 20) OUTPUT,
   @nAfterStep      INT      
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @bSuccess    INT   
   DECLARE @nExists     INT
   DECLARE @cShort      NVARCHAR(20)
   DECLARE @cWCS        NVARCHAR(1)
   DECLARE @cCaseID     NVARCHAR(20)
   DECLARE @cListKey    NVARCHAR(10)
   DECLARE @cUserName   NVARCHAR(18)
   DECLARE @cStorerKey  NVARCHAR(15)
   DECLARE @cFacility   NVARCHAR(5)
   
   
   SELECT 
      @cUserName = userName,
      @cStorerKey = StorerKey,
      @cFacility = Facility 
   FROM rdt.RDTMOBREC WITH (NOLOCK)
   WHERE mobile = @nMobile
   
   -- TM Case Pick
   IF @nFunc = 1812
   BEGIN
      IF @nStep = 6 -- ToLOC
      BEGIN
         IF @nInputKey = 1 
         BEGIN
         	SELECT    
               @cListKey = listKey
            FROM dbo.TaskDetail WITH (NOLOCK)    
            WHERE TaskDetailKey = @cTaskDetailKey  
            
            -- Get storer config    
            EXEC nspGetRight  
               @c_Facility   = @cFacility    
            ,  @c_StorerKey  = @cStorerKey   
            ,  @c_sku        = ''         
            ,  @c_ConfigKey  = 'WCS'   
            ,  @b_Success    = @bSuccess  OUTPUT  
            ,  @c_authority  = @cWCS      OUTPUT   
            ,  @n_err        = @nErrNo    OUTPUT  
            ,  @c_errmsg     = @cErrMsg   OUTPUT 

      
            SELECT 
               @nExists = 1 
            FROM codelkup WITH (NOLOCK) 
            WHERE storerKey = @cStorerKey 
            AND listName = 'WSWCSITF'
            AND code = @nFunc
            
            IF (@cWCS = '1') AND  @nExists = 1 
            BEGIN
            	DECLARE @curRPTask CURSOR  
               SET @curRPTask = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR  
                  SELECT TaskDetailKey, caseID  
                  FROM dbo.TaskDetail WITH (NOLOCK)  
                  WHERE ListKey = @cListKey  
                     AND UserKey = @cUserName  
                     AND Status = '9' -- 3=Fetch, 5=Picked, 9=Complete  
                  ORDER BY TaskDetailKey  
               OPEN @curRPTask  
               FETCH NEXT FROM @curRPTask INTO @cTaskDetailKey, @cCaseID
               WHILE @@FETCH_STATUS = 0  
               BEGIN  
               	IF NOT EXISTS (SELECT 1 FROM dbo.TRANSMITLOG2 WITH (NOLOCK) WHERE key1 = @cTaskdetailKey AND Key2 = @cCaseID)
            	   BEGIN
            		   SELECT 
                        @cShort = short 
                     FROM codelkup WITH (NOLOCK) 
                     WHERE storerKey = @cStorerKey 
                     AND listName = 'WSWCSITF'
                     AND code = @nFunc
               
            
      	            EXEC dbo.ispGenTransmitLog2  
                        @c_TableName      = @cShort,  
                        @c_Key1           = @cTaskdetailKey,  
                        @c_Key2           = @cCaseID ,  
                        @c_Key3           = @cStorerKey,  
                        @c_TransmitBatch  = '',  
                        @b_success        = @bSuccess    OUTPUT,  
                        @n_err            = @nErrNo      OUTPUT,  
                        @c_errmsg         = @cErrMsg     OUTPUT  
  
                     IF @bSuccess <> 1  
                     BEGIN  
                        SET @nErrNo = 175751  
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'GenTLog2 Fail'  
                        GOTO Quit  
                     End  
            	   END
               	
               	FETCH NEXT FROM @curRPTask INTO @cTaskDetailKey, @cCaseID
               END
            END            	
         END
      END
   END

Quit:


END

GO