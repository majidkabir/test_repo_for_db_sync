SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*************************************************************************/  
/* Stored Procedure: isp_EXG_Construct_FileName                          */  
/* Creation Date: 15 Jun 2020                                            */  
/* Copyright: LFL                                                        */  
/* Written by: GuanHao Chan                                              */  
/*                                                                       */  
/* Purpose: Excel Generator construct filename based on filename pattern.*/  
/*                                                                       */  
/* Called By:  ExcelGenerator                                            */  
/*                                                                       */  
/* PVCS Version: -                                                       */  
/*                                                                       */  
/* Updates:                                                              */  
/* Date          Author   Ver  Purposes                                  */  
/* 15-Jun-2020   GHChan   1.0  Initial Development                       */
/* 18-Feb-2021   GHChan   2.0  Update Generic SP name                    */
/*************************************************************************/  
  
CREATE PROCEDURE [dbo].[isp_EXG_Construct_FileName]  
(  @c_Username    NVARCHAR(200)  = ''  
,  @n_EXG_Hdr_ID  INT            = 0  
,  @c_FileNameFormat NVARCHAR(200)  = ''  
,  @c_ParamVal1   NVARCHAR(200)  = ''  
,  @c_ParamVal2   NVARCHAR(200)  = ''  
,  @c_ParamVal3   NVARCHAR(200)  = ''  
,  @c_ParamVal4   NVARCHAR(200)  = ''  
,  @c_ParamVal5   NVARCHAR(200)  = ''  
,  @c_ParamVal6   NVARCHAR(200)  = ''  
,  @c_ParamVal7   NVARCHAR(200)  = ''  
,  @c_ParamVal8   NVARCHAR(200)  = ''  
,  @c_ParamVal9   NVARCHAR(200)  = ''  
,  @c_ParamVal10  NVARCHAR(200)  = ''  
,  @c_FileKeyList NVARCHAR(500)  = ''  OUTPUT  
,  @b_Debug       INT            = 1  
,  @b_Success     INT            = 1   OUTPUT  
,  @n_Err         INT            = 0   OUTPUT  
,  @c_ErrMsg      NVARCHAR(250)  = ''  OUTPUT   
)  
AS  
BEGIN  
   SET NOCOUNT ON   
   SET ANSI_NULLS OFF  
   SET QUOTED_IDENTIFIER OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   /*********************************************/  
   /* Variables Declaration (Start)             */  
   /*********************************************/  
  
   DECLARE @n_Continue  INT           = 1  
         , @n_StartTcnt INT           = @@TRANCOUNT  
         , @n_ITFErr    INT           = 0  
         , @c_ITFErrMsg NVARCHAR(250) = ''  
         , @c_AllParamsVal NVARCHAR(2000)= ''  
                                   
         , @c_SPName    NVARCHAR(200) = ''  
   /*********************************************/  
   /* Variables Declaration (End)               */  
   /*********************************************/  
  
 IF @b_Debug = 1  
   BEGIN  
      PRINT '[dbo].[isp_EXG_Construct_FileName]: Start...'  
      PRINT '[dbo].[isp_EXG_Construct_FileName]: '  
          + ' @c_Username=' + ISNULL(RTRIM(@c_Username), '')  
          + ' @n_EXG_Hdr_ID=' + ISNULL(RTRIM(@n_EXG_Hdr_ID), '')  
          + ',@c_FileNameFormat='   + ISNULL(RTRIM(@c_FileNameFormat), '')  
          + ',@c_ParamVal1='  + ISNULL(RTRIM(@c_ParamVal1), '')  
          + ',@c_ParamVal2='  + ISNULL(RTRIM(@c_ParamVal2), '')  
          + ',@c_ParamVal3='  + ISNULL(RTRIM(@c_ParamVal3), '')  
          + ',@c_ParamVal4='  + ISNULL(RTRIM(@c_ParamVal4), '')  
          + ',@c_ParamVal5='  + ISNULL(RTRIM(@c_ParamVal5), '')  
          + ',@c_ParamVal6='  + ISNULL(RTRIM(@c_ParamVal6), '')  
          + ',@c_ParamVal7='  + ISNULL(RTRIM(@c_ParamVal7), '')  
          + ',@c_ParamVal8='  + ISNULL(RTRIM(@c_ParamVal8), '')  
          + ',@c_ParamVal9='  + ISNULL(RTRIM(@c_ParamVal9), '')  
          + ',@c_ParamVal10=' + ISNULL(RTRIM(@c_ParamVal10), '')  
   END  
  
   IF @n_EXG_Hdr_ID <= 0  
   BEGIN  
         SET @n_Err = 200001  
         SET @c_ErrMsg = 'Invalid EXG Hdr ID. (isp_EXG_Construct_FileName)'  
         SET @n_Continue = 3  
         GOTO QUIT  
   END  
  
   IF ISNULL(RTRIM(@c_FileNameFormat), '') = ''  
   BEGIN  
         SELECT @c_FileNameFormat = [FileName]   
         FROM [GTApps].[dbo].[EXG_Hdr] WITH (NOLOCK)   
         WHERE EXG_Hdr_ID = @n_EXG_Hdr_ID  
   END  
  
   SELECT @c_SPName = Lbl.SPName  
   FROM [GTApps].[dbo].[EXG_Hdr] Hdr WITH (NOLOCK)  
   INNER JOIN [GTApps].[dbo].[EXG_LblParams] Lbl WITH (NOLOCK)  
   ON Hdr.EXG_Param_ID = Lbl.EXG_Param_ID  
   WHERE EXG_Hdr_ID = @n_EXG_Hdr_ID  
  
   IF ISNULL(RTRIM(@c_SPName), '') = ''  
   BEGIN  
      SET @n_Err = 200002  
      SET @c_ErrMsg = 'Invalid EXG Param Stored Procedure cannot be empty or null. (isp_EXG_Construct_FileName)'  
      SET @n_Continue = 3  
      GOTO QUIT  
   END  
  
   SET @c_AllParamsVal = ISNULL(RTRIM(@c_ParamVal1),'') + ';'  
                       + ISNULL(RTRIM(@c_ParamVal2),'') + ';'  
                       + ISNULL(RTRIM(@c_ParamVal3),'') + ';'  
                       + ISNULL(RTRIM(@c_ParamVal4),'') + ';'  
                       + ISNULL(RTRIM(@c_ParamVal5),'') + ';'  
                       + ISNULL(RTRIM(@c_ParamVal6),'') + ';'  
                       + ISNULL(RTRIM(@c_ParamVal7),'') + ';'  
                       + ISNULL(RTRIM(@c_ParamVal8),'') + ';'  
                       + ISNULL(RTRIM(@c_ParamVal9),'') + ';'  
                       + ISNULL(RTRIM(@c_ParamVal10),'')  
  
   BEGIN TRY  
      EXEC  @c_SPName  
            @c_Username     
         ,  @n_EXG_Hdr_ID   
         ,  @c_FileNameFormat  
         ,  @c_ParamVal1    
         ,  @c_ParamVal2     
         ,  @c_ParamVal3     
         ,  @c_ParamVal4     
         ,  @c_ParamVal5     
         ,  @c_ParamVal6     
         ,  @c_ParamVal7     
         ,  @c_ParamVal8     
         ,  @c_ParamVal9     
         ,  @c_ParamVal10    
         ,  @c_FileKeyList  OUTPUT  
         ,  @b_Debug     
         ,  @b_Success      OUTPUT  
         ,  @n_Err          OUTPUT  
         ,  @c_ErrMsg       OUTPUT  
  
      IF ISNULL(RTRIM(@c_ErrMsg), '') <> ''  
      BEGIN  
         SET @n_Err = @n_Err  
         SET @c_ErrMsg = @c_ErrMsg  
         GOTO QUIT  
      END  
  
      IF ISNULL(RTRIM(@c_FileKeyList), '') = ''  
      BEGIN  
         SET @n_Err = 200003  
         SET @c_ErrMsg = 'No records have been found! (isp_EXG_Construct_FileName)'  
         SET @n_Continue = 3  
         GOTO QUIT  
      END  
  
      EXEC [dbo].[isp_EXG_Main]  
            @c_FileKeyList  
         ,  @b_Debug        
         ,  @b_Success      OUTPUT  
         ,  @n_Err          OUTPUT  
         ,  @c_ErrMsg       OUTPUT  
  
      IF ISNULL(RTRIM(@c_ErrMsg), '') <> ''  
      BEGIN  
         SET @n_Err = @n_Err  
         SET @c_ErrMsg = @c_ErrMsg  
         GOTO QUIT  
      END  
  
   END TRY  
   BEGIN CATCH   
      WHILE @@TRANCOUNT > 0  
         ROLLBACK TRAN  
           
      SELECT @n_ITFErr = ERROR_NUMBER(), @c_ITFErrMsg = ERROR_MESSAGE()  
           
      SET @n_Err = @n_ITFErr  
      SET @c_ErrMsg = LTRIM(RTRIM(@c_ITFErrMsg)) + ' (isp_EXG_Construct_FileName)'  
                 
      IF @b_Debug = 1  
      BEGIN  
         PRINT '[isp_EXG_Construct_FileName]: Execute SP Name Failed...'   
               + ' @c_ErrMsg=' + @c_ErrMsg  
      END  
      GOTO QUIT  
   END CATCH  
  
QUIT:  
   WHILE @@TRANCOUNT > 0  
      COMMIT TRAN  
  
   WHILE @@TRANCOUNT < @n_StartTCnt        
      BEGIN TRAN   
  
   IF  ISNULL(RTRIM(@c_Username), '') = 'QCmdUser'  
   AND ISNULL(RTRIM(@c_ErrMsg), '') <> ''  
   BEGIN  
      BEGIN TRAN  
      INSERT INTO GTApps.dbo.EXG_Log (PID  
                                    , MachineName  
                                    , Logdate  
                                    , FunctionName  
                                    , EXG_Hdr_ID  
                                    , ParamsVal  
                                    , ExceptionMsg  
                                    , ExceptionType  
                                    , ExceptionStackTrace  
                                    , ExceptionSource  
                                    , Username  
 , PrgVersion  
                                    , BackendRun)  
                              VALUES ( ''  
                                    , HOST_NAME()  
                                    , GETDATE()  
                                    , ''  
                                    , @n_EXG_Hdr_ID  
                                    , @c_AllParamsVal  
                                    , @c_ErrMsg  
                                    , 'SQL Exception'  
                                    , CAST(@n_Err AS NVARCHAR(10))  
                                    , ''  
                                    , @c_Username  
                                    , ''  
                                    , '1')  
      COMMIT TRAN  
   END  
  
   IF @n_Continue=3  -- Error Occured - Process And Return        
   BEGIN        
      SELECT @b_success = 0        
      IF @@TRANCOUNT > @n_StartTCnt        
      BEGIN                 
         ROLLBACK TRAN        
      END        
      ELSE        
      BEGIN        
         WHILE @@TRANCOUNT > @n_StartTCnt        
         BEGIN        
            COMMIT TRAN        
         END        
      END     
  
      IF @b_Debug = 1  
      BEGIN  
         PRINT '[dbo].[isp_EXG_Construct_FileName]: @c_ErrMsg=' + RTRIM(@c_ErrMsg)  
         PRINT '[dbo].[isp_EXG_Construct_FileName]: @b_Success=' + RTRIM(CAST(@b_Success AS NVARCHAR))  
      END  
  
      RETURN        
   END        
   ELSE        
   BEGIN  
      IF ISNULL(RTRIM(@c_ErrMsg), '') <> ''   
      BEGIN  
         SELECT @b_Success = 0  
      END  
      ELSE  
      BEGIN   
         SELECT @b_Success = 1   
      END          
  
      WHILE @@TRANCOUNT > @n_StartTCnt        
      BEGIN        
         COMMIT TRAN        
      END       
        
      IF @b_Debug = 1  
      BEGIN  
         PRINT '[dbo].[isp_EXG_Construct_FileName]: @c_ErrMsg=' + RTRIM(@c_ErrMsg)  
         PRINT '[dbo].[isp_EXG_Construct_FileName]: @b_Success=' + RTRIM(CAST(@b_Success AS NVARCHAR))  
      END        
      RETURN        
   END          
   /***********************************************/        
   /* Std - Error Handling (End)                  */        
   /***********************************************/      
END --End Procedure

GO