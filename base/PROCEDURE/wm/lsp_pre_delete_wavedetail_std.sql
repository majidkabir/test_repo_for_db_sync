SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/    
/* Stored Procedure: lsp_Pre_Delete_WaveDetail_STD                      */    
/* Creation Date: 03-Apr-2018                                           */    
/* Copyright: LFLogistics                                               */    
/* Written by:                                                          */    
/*                                                                      */    
/* Purpose: Orders Pre-delete process / validation                      */    
/*                                                                      */    
/* Called By: Orders delete                                             */    
/*                                                                      */    
/* PVCS Version: 1.3                                                    */    
/*                                                                      */    
/* Version: 8.0                                                         */    
/*                                                                      */    
/* Data Modifications:                                                  */    
/*                                                                      */    
/* Updates:                                                             */    
/* Date        Author   Ver   Purposes                                  */  
/* 19-Nov-2020 LZG      1.1   INC1357497 - Use RefKey2 as               */
/*                            WaveDetailKey (ZG01)                      */  
/* 2021-01-15  Wan01    1.2   Add Big Outer Begin try/Catch             */
/*                            Execute Login if @c_UserName<>SUSER_SNAME()*/
/* 2021-11-16  LZG      1.3   JSM-33161 - Corrected typo (ZG02)         */
/* 2021-11-24  Wan02    1.4   LFWM-3141 - UAT - TW  Outbound - Order    */
/*                            Remove from Wave Bug                      */
/*                      1.3   DevOps Combine Script                     */
/************************************************************************/     
CREATE PROCEDURE [WM].[lsp_Pre_Delete_WaveDetail_STD]  
      @c_StorerKey         NVARCHAR(15)  
   ,  @c_RefKey1           NVARCHAR(50)  = ''   
   ,  @c_RefKey2           NVARCHAR(50)  = ''   
   ,  @c_RefKey3           NVARCHAR(50)  = ''   
   ,  @c_RefreshHeader     CHAR(1) = 'N'        OUTPUT  
   ,  @c_RefreshDetail     CHAR(1) = 'N'        OUTPUT   
   ,  @b_Success           INT = 1              OUTPUT   --@b_success= 0: Fail, 1:Success, 2:Question  
   ,  @n_Err               INT = 0              OUTPUT  
   ,  @c_Errmsg            NVARCHAR(255) = ''   OUTPUT  
   ,  @c_UserName          NVARCHAR(128) = ''   
   ,  @c_IsSupervisor      CHAR(1) = 'N'   
AS  
BEGIN  
   SET ANSI_NULLS ON  
   SET ANSI_PADDING ON  
   SET ANSI_WARNINGS ON  
   SET QUOTED_IDENTIFIER ON  
   SET CONCAT_NULL_YIELDS_NULL ON  
   SET ARITHABORT ON  
  
   DECLARE @n_Continue                 INT = 1  
         , @n_StartTCnt                INT = @@TRANCOUNT  
  
         , @n_PickSlipCnt              INT = 0  
         , @c_Facility                 NVARCHAR(5)  = ''  
  
         , @c_WaveDetailKey            NVARCHAR(10) = ''   
         , @c_Wavekey                  NVARCHAR(10) = ''  
         , @c_Orderkey                 NVARCHAR(10) = ''   
         , @c_Status                   NVARCHAR(10) = ''  
         , @c_SOStatus                 NVARCHAR(10) = '' 
         , @c_Status_TaskDetail        NVARCHAR(10) = ''   
         
         , @c_DelSOCancCFromWave       NVARCHAR(30) = ''  
         , @c_DelUnProcessSOFromWave   NVARCHAR(30) = ''  
  
   SET @n_err=0  
   SET @b_success=1  
   SET @c_errmsg=''   
   SET @c_RefreshDetail = 'Y'  
   
   IF SUSER_SNAME() <> @c_UserName        --(Wan01) - START
   BEGIN
      EXEC [WM].[lsp_SetUser] @c_UserName = @c_UserName OUTPUT, @n_Err = @n_Err OUTPUT, @c_ErrMsg = @c_ErrMsg OUTPUT
    
      IF @n_Err <> 0 
      BEGIN
         GOTO EXIT_SP
      END
                
      EXECUTE AS LOGIN = @c_UserName        
   END                                    --(Wan01) - END
    
   BEGIN TRY                              --(Wan01) - START
      SET @c_WaveDetailKey = ISNULL(@c_RefKey2,'')       -- ZG01
  
      SELECT @c_Wavekey  = WD.Wavekey  
            ,@c_Orderkey = WD.Orderkey  
            ,@c_Facility = OH.Facility   
            ,@c_Storerkey= OH.Storerkey  
            ,@c_Status   = OH.[Status]  
            ,@c_SOStatus = OH.SOStatus  
      FROM WAVEDETAIL WD WITH (NOLOCK)  
      JOIN ORDERS OH WITH (NOLOCK) ON WD.Orderkey = OH.Orderkey  
      WHERE WD.WaveDetailKey = @c_WaveDetailKey  
  
      IF @c_WaveKey = ''  
      BEGIN  
         GOTO EXIT_SP    
      END  
           
      IF EXISTS(  SELECT 1   
                  FROM WAVE WITH (NOLOCK)  
                  WHERE Wavekey = @c_WaveKey  
                  AND Status = '9'   
                  )  
      BEGIN  
         SET @n_continue = 3  
         SET @n_err = 552351  
         SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(6),@n_err)+': Completed wave cannot not be deleted. (lsp_Pre_Delete_WaveDetail_STD)'       --(Wan02)   
         GOTO EXIT_SP               
      END                           
   
      SELECT @c_Status   = OH.[Status]  
            ,@c_SOStatus = OH.SOStatus  
      FROM ORDERS OH WITH (NOLOCK)  
      WHERE OH.Orderkey = @c_Orderkey  
  
      SELECT @c_DelSOCancCFromWave = dbo.fnc_GetRight(@c_Facility, @c_Storerkey, '', 'DelSOCancCFromWave')  
  
      IF @c_DelSOCancCFromWave = '1'  
      BEGIN  
         IF @c_Status = '0' AND @c_SOStatus = 'CANC'  -- Delete without other pre-delete validation  
         BEGIN  
            GOTO EXIT_SP    
         END  
      END  
  
      SELECT @c_DelUnProcessSOFromWave = dbo.fnc_GetRight(@c_Facility, @c_Storerkey, '', 'DelUnProcessSOFromWave')  
      IF @c_DelUnProcessSOFromWave = 1  
      BEGIN  
         IF @c_Status NOT IN ( '0', '9' )  
         BEGIN  
            SET @n_continue = 3  
            SET @n_err   = 552352               --(Wan02)  
            SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(6),@n_err)  
                           +': Preallocated/Allocated/Shipped ORDERS is not eligible to delete from this wave. (lsp_Pre_Delete_WaveDetail_STD)'   
            GOTO EXIT_SP   
         END  
      END  
      --(Wan02) - START
      SET @c_Status = ''
      SELECT TOP 1 @c_Status = p.[Status]
      FROM dbo.PICKDETAIL AS p WITH (NOLOCK)
      WHERE p.OrderKey = @c_Orderkey
      AND p.[Status] >= '3'
      --(Wan02) - END

      IF @c_Status >= '3'  
      BEGIN  
         SET @n_continue = 3  
         SET @n_err   = 552353                  --(Wan02)  
         SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(6),@n_err)  
                        +': Picks are already in progress for Order#: ' + @c_Orderkey +'. (lsp_Pre_Delete_WaveDetail_STD) |' + @c_Orderkey         --(Wan02)  
         GOTO EXIT_SP                           
      END  
      
      SET @n_PickSlipCnt = 0  
      SELECT @n_PickSlipCnt = ISNULL(SUM(CASE WHEN PH.Orderkey = @c_Orderkey THEN 1 ELSE 0 END),0)  
      --FROM WAVEDETAIL WH WITH (NOLOCK)     -- ZG02
      FROM WAVE WH WITH (NOLOCK)          -- ZG02
      JOIN WAVEDETAIL WD WITH (NOLOCK) ON  WH.Wavekey = WD.Wavekey  
      JOIN PICKHEADER PH WITH (NOLOCK) ON  PH.Wavekey = WD.Wavekey  
                                       AND PH.Orderkey= WD.Orderkey  
      WHERE WH.WaveKey = @c_WaveKey  
                         
      IF @n_PickSlipCnt > 0  
      BEGIN  
         SET @n_continue = 3  
         SET @n_err   = 552354               --(Wan02)    
         SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(6),@n_err)  
                        +': PickSlip Printed. Delete Not Allowed. (lsp_Pre_Delete_WaveDetail_STD)'                 
         GOTO EXIT_SP   
      END                           
       
      --(Wan02) - START 
      SET @c_Status_TaskDetail = '' 
      SELECT TOP 1 @c_Status_TaskDetail = CASE WHEN TD.[Status] IN ('3','9') THEN '3' ELSE '0' END
      FROM TASKDETAIL TD WITH (NOLOCK)  
      WHERE TD.WaveKey = @c_WaveKey  
      ORDER BY 1 DESC
                  
      IF @c_Status_TaskDetail <> ''
      BEGIN 
         IF @c_Status_TaskDetail = '3'
         BEGIN 
            SET @n_continue = 3                 --(Wan02)
            SET @n_err = 552355  
            SET @c_errmsg = 'NSQL'+CONVERT(NVARCHAR(6),@n_err)  
                           + ': Cannot delete this wave. The wave has task details which are In Progress and/or Completed and which may not be deleted'  
                           + '. (lsp_Pre_Delete_WaveDetail_STD)'   
            GOTO EXIT_SP   
         END    
         ELSE  
         BEGIN 
            SET @b_Success = 2 
            SET @c_errmsg = 'There are Task Details for this Wave. Delete Anyway?'  
            GOTO EXIT_SP  
         END                                                                                                                                                                                                                   
      END 
      --(Wan02) - END                 
   END TRY
   BEGIN CATCH
      SET @n_continue = 3 
      SET @c_errmsg   = ERROR_MESSAGE()
      GOTO EXIT_SP  
   END CATCH                               --(Wan01) - START
EXIT_SP:  
  
   IF @n_continue=3  -- Error Occured - Process And Return    
   BEGIN    
      SELECT @b_success = 0    
      IF @@TRANCOUNT = 1 and @@TRANCOUNT > @n_starttcnt    
      BEGIN    
         ROLLBACK TRAN    
      END    
   ELSE    
      BEGIN    
         WHILE @@TRANCOUNT > @n_starttcnt    
         BEGIN    
            COMMIT TRAN    
         END    
      END    
      execute nsp_logerror @n_err, @c_errmsg, 'lsp_Pre_Delete_WaveDetail_STD'  
      --RETURN    --(Wan01)  
   END    
   ELSE    
   BEGIN 
      --(Wan02) - START
      IF @b_Success NOT IN (2)   
      BEGIN
         SELECT @b_success = 1  
      END  
      --(Wan02) - END
      
      WHILE @@TRANCOUNT > @n_starttcnt    
      BEGIN    
         COMMIT TRAN    
      END    
      --RETURN    --(Wan01)   
   END 
   REVERT         --(Wan01)               
END -- End Procedure

GO