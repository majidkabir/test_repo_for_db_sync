SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Store procedure: isp_AutoBackendBuildLoad                            */  
/* Copyright      : LFLogistics                                         */  
/*                                                                      */  
/* Date         Rev  Author      Purposes                               */  
/* 14-Nov-2017  1.0  Shong       Initial Version                        */  
/************************************************************************/  
CREATE PROC [dbo].[isp_AutoBackendBuildLoad] ( 
     @bSuccess      INT = 1            OUTPUT
   , @nErr          INT = ''           OUTPUT
   , @cErrMsg       NVARCHAR(250) = '' OUTPUT	
	, @bDebug        INT = 1 
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cStorerKey            NVARCHAR(15),
           @cFacility             NVARCHAR(5),
           @cBL_ParamGroup        NVARCHAR(30),
           @cBL_ParameterCode     NVARCHAR(10),
           @cBL_ParmDesc          NVARCHAR(60),
           @cBL_Priority          NVARCHAR(60),
           @cBL_AllocStrategy     NVARCHAR(60), 
           @nSuccess              INT,    
           @cErrorMsg             NVARCHAR(256),        
           @cSQLSelect            NVARCHAR(MAX),
           @cSQLCondition         NVARCHAR(MAX),               
           @cBatchNo              NVARCHAR(10), 
           @nWherePosition        INT, 
           @nGroupByPosition      INT, 
           @cOrderKey             NVARCHAR(10), 
           @cSQLParms             NVARCHAR(1000),
           @nAllocBatchNo         BIGINT, 
           @nOrderCnt             INT, 
           @nErrNo                INT, 
           @cSKU                  NVARCHAR(20), 
           @nPrevAllocBatchNo     BIGINT, 
           @dOrderAddDate         DATETIME,
           @cCommand              NVARCHAR(2014), 
           @cAllocBatchNo         NVARCHAR(10) 

   DECLARE C_BuiLoadParameters CURSOR LOCAL FAST_FORWARD READ_ONLY 
   FOR
       SELECT StorerKey,
              Facility,
              BL_ParamGroup,
              BL_ParameterCode,
              BL_ParmDesc,
              BL_Priority,
              BL_AllocStrategy, 
              [BL_BuildType]
       FROM  V_Build_Load_Parm_Header 
       WHERE [BL_BuildType] <> 'BACKENDALLOC'
       ORDER BY BL_Priority, BL_ParamGroup, BL_ParameterCode
     
   OPEN C_BuiLoadParameters

   FETCH FROM C_BuiLoadParameters INTO @cStorerKey, @cFacility, @cBL_ParamGroup,
                             @cBL_ParameterCode, @cBL_ParmDesc, @cBL_Priority,
                             @cBL_AllocStrategy

   WHILE @@FETCH_STATUS = 0
   BEGIN            
      EXEC [dbo].[isp_Build_Loadplan]                                                                                                                       
         @cParmCode    =  @cBL_ParameterCode,                                                                                                              
         @cFacility    =  @cFacility,                                                                                                               
         @cStorerKey   =  @cStorerKey,                                                                                                              
         @nSuccess     =  @nSuccess OUTPUT,                                                                                               
         @cErrorMsg    =  @cErrorMsg OUTPUT,                                                                                               
         @bDebug       =  0,                                                                                               
         @cSQLPreview  =  @cSQLSelect OUTPUT,                                                                                               
         @cBatchNo     =  @cBatchNo OUTPUT,
         @cOrderStatusFlag = 'F'             
      
      IF @bDebug = 1
      BEGIN
         PRINT @cSQLSelect

         SELECT bll.BatchNo, bll.Facility, bll.Storerkey, bll.TotalLoadCnt 
         FROM BuildLoadLog AS bll WITH(NOLOCK)
         WHERE bll.BatchNo = @cBatchNo         
      END         
      
      
      FETCH_NEXT:
   
      FETCH FROM C_BuiLoadParameters INTO 
                 @cStorerKey,        @cFacility,    @cBL_ParamGroup,
                 @cBL_ParameterCode, @cBL_ParmDesc, @cBL_Priority,
                 @cBL_AllocStrategy
   END
              
   CLOSE C_BuiLoadParameters
   DEALLOCATE C_BuiLoadParameters


END -- Procedure

GO