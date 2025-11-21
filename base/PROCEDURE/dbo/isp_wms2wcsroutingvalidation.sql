SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Trigger:  isp_WMS2WCSRoutingValidation                               */  
/* Creation Date: 05-Jul-2010                                           */  
/* Copyright: IDS                                                       */  
/* Written by: AQSACM                                                   */  
/*                                                                      */  
/* Purpose:  C/R : DO NOT allow multiple BOX Number (Tote/CaseID) with  */  
/*                 STATE_HCOM  = '10' And actionflag = 'INSERT?         */  
/*                                                                      */  
/* PVCS Version: 1.1                                                    */  
/*                                                                      */  
/* Version: 5.4                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author    Ver.  Purposes                                */  
/* 08-Jul-2013  Shong     1.1   Target Table Not UNICODE                */
/************************************************************************/  
CREATE PROCEDURE [dbo].[isp_WMS2WCSRoutingValidation]   
       @c_ToteNo     NVARCHAR(18)  
     , @c_Storerkey  NVARCHAR(15)  
     , @b_Success    int        OUTPUT  
     , @n_err        int        OUTPUT  
     , @c_errmsg     NVARCHAR(250)  OUTPUT        
  
AS  
BEGIN  
   SET NOCOUNT ON   -- SQL 2005 Standard  
   SET QUOTED_IDENTIFIER OFF   
   SET ANSI_NULLS OFF     
   SET CONCAT_NULL_YIELDS_NULL OFF          
  
 DECLARE    @c_ActionFlag     VARCHAR(6),  
            @c_TargetDBName   NVARCHAR(20),   
            @n_recordCnt      INT,  
            @n_BoxNo          INT  
      
   DECLARE  @c_ExecStatements    NVARCHAR(4000) ,  
            @c_ExecArguments     NVARCHAR(4000)  ,  
            @n_continue          INT,  
            @b_Debug             INT,  
            @n_starttcnt         int  
  
   SELECT @n_continue = 1, @b_success = 1, @n_err = 0  
   SET @n_StartTCnt=@@TRANCOUNT   
   SET @b_Debug = 0  
  
   -- set constant values  
   SET @c_ActionFlag = 'INSERT'  
   SET @c_ExecStatements = ''  
   SET @c_ExecArguments = ''   
   SET @c_TargetDBName = ''  
   SET @n_recordCnt = 0  
   SET @n_BoxNo = 0  
  
  
   IF LEN(ISNULL(RTRIM(@c_ToteNo),'')) > 8   
   BEGIN  
      SELECT @n_continue = 3  
      SELECT @n_err = 70409    
      SELECT @c_errmsg = 'ToteNo > 8 Digit'  
      GOTO QUIT_SP  
   END  
  
   IF ISNULL(RTRIM(@c_ToteNo),'') =''   
   BEGIN  
      SELECT @n_continue = 3  
      SELECT @n_err = 70869    
      SELECT @c_errmsg = 'ToteNo Empty'  
      GOTO QUIT_SP  
   END  
  
   IF ISNUMERIC(@c_ToteNo) <> 1   
   BEGIN  
      SELECT @n_continue = 3  
      SELECT @n_err = 70405    
      SELECT @c_errmsg = 'ToteNo Not Numeric'  
      GOTO QUIT_SP  
   END  
  
   SET @n_BoxNo = CAST (@c_ToteNo AS INT)  
  
   IF @n_BoxNo <= 0  
   BEGIN  
      SELECT @n_continue = 3  
      SELECT @n_err = 70870    
      SELECT @c_errmsg = 'ToteNo <=0'  
      GOTO QUIT_SP  
   END  
  
  
 SELECT @c_TargetDBName = UPPER(SValue)  
 FROM   dbo.StorerConfig WITH (NOLOCK)  
 WHERE  CONFIGKEY = 'REPWCSDB'   
   AND Storerkey = @c_StorerKey  
  
   IF ISNULL(RTRIM(@c_TargetDBName),'') = ''    
   BEGIN  
      SET @n_continue = 3  
      SET @n_err = 70406  
      SET @c_errmsg = 'TargetDB Is Blank'  
      GOTO QUIT_SP  
   END  
  
   BEGIN TRY  
      SET @c_ExecStatements = N'SELECT @n_recordCnt = COUNT(*) '  
                              + 'FROM ' + RTRIM(@c_TargetDBName) + '.dbo.ORDER_HEADER (NOLOCK) '  
                              + 'WHERE STATE_HCOM = ''10'' '  
                              + 'AND  ACTION   = @c_ActionFlag '  
                              + 'AND  BOXNUMBER   = @n_BoxNo '  
     
      SET @c_ExecArguments = N'@c_TargetDBName NVARCHAR(20), ' +  
                              '@c_ActionFlag   VARCHAR(6), ' +   
                              '@n_BoxNo      INT, ' +   
                              '@n_recordCnt  INT OUTPUT '    
     
      EXEC sp_ExecuteSql @c_ExecStatements   
                       , @c_ExecArguments    
                       , @c_TargetDBName  
                       , @c_ActionFlag     
                       , @n_BoxNo     
                       , @n_recordCnt OUTPUT  
   END TRY  
   BEGIN CATCH  
      SET @n_continue = 3  
      SET @n_err = 70407   
      SET @c_errmsg = 'Invalid TargetDB'  
      GOTO QUIT_SP  
  
   END CATCH;  
  
   IF @n_recordCnt > 0   
   BEGIN  
      SET @n_continue = 3  
      SET @n_err = 70408   
      SET @c_errmsg = 'Tote in use'  
      GOTO QUIT_SP  
   END  
  
   QUIT_SP:  
  
   IF @n_continue = 3  -- Error Occured - Process And Return  
   BEGIN  
      SELECT @b_success = 0  
   END  
   ELSE  
   BEGIN  
      SELECT @b_success = 1  
   END  
  
   IF @b_Debug = 1   
      select '@b_success',@b_success,'@n_continue',@n_continue,'@n_err',@n_err,'@c_errmsg',@c_errmsg  
  
   RETURN  
END  

GO