SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/    
/* Stored Procedure: ispUnallocate_TMLoadPlan_Wrapper                   */    
/* Creation Date: 16-Nov-2010                                           */    
/* Copyright: IDS                                                       */    
/* Written by: AQSKC                                                    */    
/*                                                                      */    
/* Purpose: SOS#195929 - Unallocate TM LoadPlan                         */    
/*                                                                      */    
/* Called By: Load Plan (Call ispUATMLP01)                              */    
/*                                                                      */    
/* PVCS Version: 1.0                                                    */    
/*                                                                      */    
/* Version: 5.4                                                         */    
/*                                                                      */    
/* Data Modifications:                                                  */    
/*                                                                      */    
/* Updates:                                                             */    
/* Date         Author   Ver  Purposes                                  */
/* 2010-12-03   ChewKP      Revise Coding to avoid DB Locking (ChewKP01)*/    
/************************************************************************/     
CREATE PROCEDURE [dbo].[ispUnallocate_TMLoadPlan_Wrapper]    
   @c_Storerkey  NVARCHAR(15),
   @c_LoadKey    NVARCHAR(10)
AS    
BEGIN    
   SET NOCOUNT ON     
   SET QUOTED_IDENTIFIER OFF     
   SET ANSI_NULLS OFF     
   SET CONCAT_NULL_YIELDS_NULL OFF    
     
   DECLARE @n_continue      INT,  
           @c_SPCode        NVARCHAR(10),  
           @c_SQL           NVARCHAR(MAX),
           @c_ErrMsg        NVARCHAR(255),
           @n_Err           INT,
           @b_Success       INT,
           @n_ErrorCnt      INT,  
           @n_starttcnt     INT
   DECLARE @c_OrderKey      NVARCHAR(10)           
   
   DECLARE    @d_StartTime    DATETIME,  
              @d_EndTime      DATETIME,  
              @d_Step1        DATETIME,  
              @d_Step2        DATETIME,  
              @d_Step3        DATETIME,  
              @d_Step4        DATETIME,  
              @d_Step5        DATETIME,   
              @c_Col1         NVARCHAR(20),  
              @c_Col2         NVARCHAR(20),  
              @c_Col3         NVARCHAR(20),  
              @c_Col4         NVARCHAR(20),  
              @c_Col5         NVARCHAR(20),  
              @c_TraceName    NVARCHAR(80),
              @d_StartDTTime  DATETIME
            
   SET @d_StartTime = GETDATE()  
  
   SET @c_TraceName = 'ispUnallocate_TMLoadPlan_Wrapper'    
   SET @c_Col5      = @@SPID
   
           
   SELECT @n_starttcnt=@@TRANCOUNT
                                                        
   SELECT @c_SPCode = '', @n_err=0, @b_success=1, @c_errmsg=''  
   

      
      
   /********************************************/
   /* Validations                              */
   /********************************************/
   -- Check blank Storerkey  
   IF ISNULL(RTRIM(@c_Storerkey), '') = ''  
   BEGIN  
       SELECT @n_continue = 3    
       SELECT @c_ErrMsg = CONVERT(CHAR(250), @n_Err),  
              @n_Err = 30001
       SELECT @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err) +   
              ': Storerkey is blank (ispUnallocate_TMLoadPlan_Wrapper)'    
       GOTO QUIT_SP  
   END 
   -- Check blank LoadKey  
   IF ISNULL(RTRIM(@c_LoadKey), '') = ''  
   BEGIN  
       SELECT @n_continue = 3    
       SELECT @c_ErrMsg = CONVERT(CHAR(250), @n_Err),  
              @n_Err = 30002
       SELECT @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err) +   
              ': Loadkey is blank (ispUnallocate_TMLoadPlan_Wrapper)'    
       GOTO QUIT_SP  
   END     
        
   -- Check LoadKey exists  
    IF NOT EXISTS (SELECT 1 FROM LOADPLAN WITH (NOLOCK)  
                  WHERE isnull(LoadKey,'') = @c_LoadKey )  
   BEGIN  
       SELECT @n_continue = 3    
       SELECT @c_ErrMsg = CONVERT(CHAR(250), @n_Err),  
              @n_Err = 30003
       SELECT @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err) +   
              ': Loadkey not found (ispUnallocate_TMLoadPlan_Wrapper)'    
       GOTO QUIT_SP  
   END  

    -- Check LoadKey closed  
    IF EXISTS (SELECT 1 FROM LOADPLAN WITH (NOLOCK)  
             WHERE isnull(LoadKey,'') = @c_LoadKey   
               AND   Status = '9' )  
   BEGIN  
       SELECT @n_continue = 3    
       SELECT @c_ErrMsg = CONVERT(CHAR(250), @n_Err),  
              @n_Err = 30004
       SELECT @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err) +   
              ': Loadkey is closed (ispUnallocate_TMLoadPlan_Wrapper)'    
       GOTO QUIT_SP  
   END  


   -- Check if LoadKey exists in Wave
   IF NOT EXISTS (SELECT 1 FROM ORDERS OH WITH (NOLOCK)
                  INNER JOIN LOADPLAN LP WITH (NOLOCK) ON (OH.LoadKey = LP.LoadKey)
                  WHERE OH.Storerkey = @c_Storerkey
                  AND   OH.LoadKey = @c_LoadKey )
   BEGIN
       SELECT @n_continue = 3    
       SELECT @c_ErrMsg = CONVERT(CHAR(250), @n_Err),  
              @n_Err = 30005
       SELECT @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err) +   
              ': LoadKey Not Found (ispUnallocate_TMLoadPlan_Wrapper)'    
       GOTO QUIT_SP        
   END

      -- Is Task Genareted?
      IF NOT EXISTS (SELECT 1 FROM TASKDETAIL WITH (NOLOCK)
                     WHERE LoadKey = @c_LoadKey )
      BEGIN
       SELECT @n_continue = 3    
       SELECT @c_ErrMsg = CONVERT(CHAR(250), @n_Err),  
              @n_Err = 30006
       SELECT @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err) +   
              ': LoadKey Not Found (ispUnallocate_TMLoadPlan_Wrapper)'    
       GOTO QUIT_SP 
      END

      
      -- Check if TaskDetail exists
      IF EXISTS (SELECT 1 FROM TASKDETAIL WITH (NOLOCK)
                 WHERE LoadKey = @c_LoadKey 
                 AND   TaskType IN ('PK', 'DPK', 'SPK')
                 AND   STATUS NOT IN ('9','X')  )
      BEGIN
       SELECT @n_continue = 3    
       SELECT @c_ErrMsg = CONVERT(CHAR(250), @n_Err),  
              @n_Err = 30007
       SELECT @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err) +   
              ': Please Cancel Pick Task Before Proceed (ispUnallocate_TMLoadPlan_Wrapper)'    
       GOTO QUIT_SP
      END
      
      -- Any Packed Qty?
      IF NOT EXISTS (SELECT 1 FROM PICKHEADER PH WITH (NOLOCK)
                     INNER JOIN PACKDETAIL PD WITH (NOLOCK) ON (PH.PickHeaderKey = PD.PickSlipNo)
                     WHERE PH.ExternOrderkey = @c_LoadKey
                     AND   PD.Qty > 0  )
      BEGIN
          SELECT @n_continue = 3    
          SELECT @c_ErrMsg = CONVERT(CHAR(250), @n_Err),  
                 @n_Err = 30008
          SELECT @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err) +   
                 ': Packing Not Done yet (ispUnallocate_TMLoadPlan_Wrapper)'    
          GOTO QUIT_SP         
      END      
      
--   SELECT @c_Storerkey = MAX(ORDERS.Storerkey)  
--   FROM LOADPLANDETAIL (NOLOCK)  
--   JOIN ORDERS (NOLOCK) ON (LOADPLANDETAIL.Orderkey = ORDERS.Orderkey)  
--   WHERE LOADPLANDETAIL.Loadkey = @c_LoadKey      
--     
   SELECT @c_SPCode = sVALUE   
   FROM   StorerConfig WITH (NOLOCK)   
   WHERE  StorerKey = @c_StorerKey  
   AND    ConfigKey = 'UNALLOCATETMLP'    
  
   IF ISNULL(RTRIM(@c_SPCode),'') =''  
   BEGIN  
       SELECT @n_continue = 3    
       SELECT @c_ErrMsg = CONVERT(CHAR(250), @n_Err),  
              @n_Err = 31011 -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
       SELECT @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err) +   
              ': Please Setup Stored Procedure Name into Storer Configuration for ' + RTRIM(@c_StorerKey) +' (ispUnallocate_TMLoadPlan_Wrapper)'    
       GOTO QUIT_SP  
   END  
     
   IF NOT EXISTS (SELECT 1 FROM dbo.sysobjects WHERE name = RTRIM(@c_SPCode) AND type = 'P')  
   BEGIN  
       SELECT @n_continue = 3    
       SELECT @c_ErrMsg = CONVERT(CHAR(250), @n_Err),  
              @n_Err = 31012 -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
       SELECT @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err) +   
              ': Storerconfig UNALLOCATETMLP - Stored Proc name invalid ('+RTRIM(ISNULL(@c_SPCode,''))+') (ispUnallocate_TMLoadPlan_Wrapper)'    
       GOTO QUIT_SP  
   END  
  
   --create temp table
   CREATE TABLE #TempResult (  
         ErrorCode         NVARCHAR(10),  
         Remarks           NVARCHAR(255)   NULL,  
         Loadkey           NVARCHAR(10)    NULL ,  
         Orderkey          NVARCHAR(10)    NULL,  
         OrderLineNumber   NVARCHAR(5)     NULL,  
         SKU               NVARCHAR(20)    NULL,  
         Lot               NVARCHAR(10)    NULL,  
         Loc               NVARCHAR(10)    NULL,  
         Status            NVARCHAR(10)    NULL,  
         Qty               INT            NULL,  
         DropID            NVARCHAR(18)    NULL,  
         LabelPrinted      NVARCHAR(10)    NULL,  
         ManifestPrinted   NVARCHAR(10)    NULL,  
         )  
         
      --(ChewKP01)
      WHILE @@TRANCOUNT > 0
      BEGIN
         COMMIT TRAN
      END 
      
      -- TraceInfo (tlting01) - Start  
      
      SET @d_EndTime = GETDATE()  
      INSERT INTO TraceInfo (TraceName, TimeIn, TimeOut, TotalTime,  
                             Step1, Step2, Step3, Step4, Step5,  
                             Col1, Col2, Col3, Col4, Col5)  
      VALUES  
         (RTRIM(@c_TraceName), @d_StartTime, @d_EndTime  
         ,CONVERT(CHAR(12),@d_EndTime - @d_StartTime ,114)  
         ,CONVERT(CHAR(12),@d_Step1,114)  
         ,CONVERT(CHAR(12),@d_Step2,114)  
         ,CONVERT(CHAR(12),@d_Step3,114)  
         ,CONVERT(CHAR(12),@d_Step4,114)  
         ,CONVERT(CHAR(12),@d_Step5,114)  
         ,@c_Loadkey,@c_Col2,@c_Col3,@c_Col4,@c_Col5)  
        
         SET @d_Step1 = NULL  
         SET @d_Step2 = NULL  
         SET @d_Step3 = NULL  
         SET @d_Step4 = NULL  
         SET @d_Step5 = NULL  
       
      -- TraceInfo (tlting01) - End     
            
   DECLARE Cursor_Orders CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT OrderKey
   FROM LoadPlanDetail (NOLOCK)
   WHERE Loadkey = @c_LoadKey
   
   OPEN Cursor_Orders 
   
   FETCH NEXT FROM Cursor_Orders INTO @c_OrderKey
   WHILE @@FETCH_STATUS <> -1
   BEGIN
      
       SET @d_StartDTTime = GETDATE()  
      
      --(ChewKP01)
      WHILE @@TRANCOUNT > 0
      BEGIN
         COMMIT TRAN
      END 
      
         
         
      BEGIN TRAN      
             
      SET @c_SQL = 'INSERT INTO #TempResult ' + master.dbo.fnc_GetCharASCII(13) +
                   'EXEC ' + @c_SPCode + ' @c_Storerkey, @c_LoadKey, @c_OrderKey, @b_Success OUTPUT, @c_ErrMsg OUTPUT,' +  
                   ' @n_Err OUTPUT '  
            
      EXEC sp_executesql @c_SQL,   
           N'@c_Storerkey NVARCHAR(15), @c_LoadKey NVARCHAR(10), @c_OrderKey NVARCHAR(10), @b_Success int OUTPUT, 
            @c_ErrMsg NVARCHAR(250) OUTPUT, @n_Err int OUTPUT ',   
           @c_Storerkey,
           @c_LoadKey,  
           @c_OrderKey,         
           @b_Success OUTPUT,                        
           @c_ErrMsg OUTPUT,
           @n_Err OUTPUT
                             
      IF @b_Success = 0  
      BEGIN  
          ROLLBACK TRAN
          SELECT @n_continue = 3    
          GOTO QUIT_SP  
      END IF @b_Success = 2
      BEGIN
        
         SET @n_continue = 3  
         GOTO SHOW_RESULT
      END

      WHILE @@TRANCOUNT > 0
      BEGIN
         COMMIT TRAN
      END  
      
      -- TraceInfo (tlting01) - Start  
      
      SET @d_EndTime = GETDATE()  
      SET @c_Col3 = 'End'
      SET @c_Col5 = cast(@@TRANCOUNT as varchar)
      
      INSERT INTO TraceInfo (TraceName, TimeIn, TimeOut, TotalTime,  
                             Step1, Step2, Step3, Step4, Step5,  
                             Col1, Col2, Col3, Col4, Col5)  
      VALUES  
         (RTRIM(@c_TraceName), @d_StartDTTime, @d_EndTime  
         ,CONVERT(CHAR(12),@d_EndTime - @d_StartTime ,114)  
         ,CONVERT(CHAR(12),@d_Step1,114)  
         ,CONVERT(CHAR(12),@d_Step2,114)  
         ,CONVERT(CHAR(12),@d_Step3,114)  
         ,CONVERT(CHAR(12),@d_Step4,114)  
         ,CONVERT(CHAR(12),@d_Step5,114)  
         ,@c_Loadkey,@c_OrderKey,@c_Col3,@c_Col4,@c_Col5)  
        
         SET @d_Step1 = NULL  
         SET @d_Step2 = NULL  
         SET @d_Step3 = NULL  
         SET @d_Step4 = NULL  
         SET @d_Step5 = NULL  
       
      -- TraceInfo (tlting01) - End   
            
      FETCH NEXT FROM Cursor_Orders INTO @c_OrderKey
   END
   CLOSE Cursor_Orders 
   DEALLOCATE Cursor_Orders 
   
    /* ----------------------------------------------- */
    /* Recalculate Qty Replen                          */
    /* ----------------------------------------------- */
   
   EXEC ispReCalculateQtyReplen
        @c_Loadkey, 
        @n_err OUTPUT,
        @c_errmsg OUTPUT
   
   IF @n_err <> 0 
   BEGIN
       SELECT @n_continue = 3    
       GOTO QUIT_SP
   END

   WHILE @@TRANCOUNT > 0
   BEGIN
      COMMIT TRAN
   END  
         
   /* -----------------------------------------------*/  
   /* RETURN Result Set                              */  
   /* -----------------------------------------------*/
   Select @n_ErrorCnt = Count(1) From  #TempResult
   IF @n_ErrorCnt = 0
   BEGIN
      INSERT INTO #TempResult (ErrorCode, Remarks )   
       VALUES('Completed','Load Successfully Unallocated')
   END

   SHOW_RESULT:
   Select ErrorCode, Remarks, Loadkey, Orderkey, OrderLineNumber, SKU, Lot,
         Loc, Status, Qty, DropID, LabelPrinted, ManifestPrinted
   From #TempResult
   Order by Orderkey 


   QUIT_SP:  
      -- TraceInfo (tlting01) - Start  
      
      SET @d_EndTime = GETDATE()  
      SET @c_Col3 = 'Process End'
      SET @c_Col5 = cast(@@TRANCOUNT as varchar)
      
      INSERT INTO TraceInfo (TraceName, TimeIn, TimeOut, TotalTime,  
                             Step1, Step2, Step3, Step4, Step5,  
                             Col1, Col2, Col3, Col4, Col5)  
      VALUES  
         (RTRIM(@c_TraceName), @d_StartTime, @d_EndTime  
         ,CONVERT(CHAR(12),@d_EndTime - @d_StartTime ,114)  
         ,CONVERT(CHAR(12),@d_Step1,114)  
         ,CONVERT(CHAR(12),@d_Step2,114)  
         ,CONVERT(CHAR(12),@d_Step3,114)  
         ,CONVERT(CHAR(12),@d_Step4,114)  
         ,CONVERT(CHAR(12),@d_Step5,114)  
         ,@c_Loadkey,@c_Col2,@c_Col3,@c_Col4,@c_Col5)  
        
         SET @d_Step1 = NULL  
         SET @d_Step2 = NULL  
         SET @d_Step3 = NULL  
         SET @d_Step4 = NULL  
         SET @d_Step5 = NULL  
       
      -- TraceInfo (tlting01) - End   
      
   --(ChewKP01)
   WHILE @@TRANCOUNT < @n_starttcnt
   BEGIN
      BEGIN TRAN
   END    
   

   IF @n_continue = 3  
   BEGIN  
       SELECT @b_success = 0  
       EXECUTE nsp_logerror @n_Err, @c_ErrMsg, 'ispUnallocate_TMLoadPlan_Wrapper'    
       RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012  
       RETURN
   END     
END    

GO