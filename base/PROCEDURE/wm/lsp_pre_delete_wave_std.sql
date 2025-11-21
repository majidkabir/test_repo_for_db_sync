SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Stored Procedure: lsp_Pre_Delete_Wave_STD                            */  
/* Creation Date: 03-Apr-2018                                           */  
/* Copyright: LFLogistics                                               */  
/* Written by:                                                          */  
/*                                                                      */  
/* Purpose: Orders Pre-delete process / validation                      */  
/*                                                                      */  
/* Called By: Orders delete                                             */  
/*                                                                      */  
/* PVCS Version: 1.0                                                    */  
/*                                                                      */  
/* Version: 8.0                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author   Ver  Purposes                                  */ 
/* 2021-02-08   mingle01 1.1  Add Big Outer Begin try/Catch             */ 
/************************************************************************/   
CREATE PROCEDURE [WM].[lsp_Pre_Delete_Wave_STD]
      @c_StorerKey         NVARCHAR(15)
   ,  @c_RefKey1           NVARCHAR(50)  = '' 
   ,  @c_RefKey2           NVARCHAR(50)  = '' 
   ,  @c_RefKey3           NVARCHAR(50)  = '' 
   ,  @c_RefreshHeader     CHAR(1) = 'N'        OUTPUT
   ,  @c_RefreshDetail     CHAR(1) = 'N'        OUTPUT 
   ,  @b_Success           INT = 1              OUTPUT   
   ,  @n_Err               INT = 0              OUTPUT
   ,  @c_Errmsg            NVARCHAR(255) = ''   OUTPUT
   ,  @c_UserName          NVARCHAR(128) = '' 
   ,  @c_IsSupervisor      CHAR(1) = 'N' 
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_Continue           INT = 1
         , @n_StartTCnt          INT = @@TRANCOUNT

         , @c_Wavekey            NVARCHAR(10) = ''
   
   SET @n_err=0
   SET @b_success=1
   SET @c_errmsg='' 
   SET @c_RefreshHeader = 'Y'
        
   SET @c_WaveKey = ISNULL(@c_RefKey1,'')
   
   --(mingle01) - START
   BEGIN TRY
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
         SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(6),@n_err)+': Completed wave may not be deleted. (lsp_Pre_Delete_Wave_STD)'   
         GOTO EXIT_SP             
      END                         
        
      IF EXISTS(  SELECT 1 
                  FROM WAVEDETAIL WH WITH (NOLOCK)
                  JOIN WAVEDETAIL WD WITH (NOLOCK) ON  WH.Wavekey = WD.Wavekey
                  JOIN PICKHEADER PH WITH (NOLOCK) ON  PH.Wavekey = WD.Wavekey
                                                   AND PH.Orderkey= WD.Orderkey
                  WHERE WH.WaveKey = @c_WaveKey
               ) 
      BEGIN
         SET @n_continue = 3
         SET @n_err   = 552352
         SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(6),@n_err)
                        +': PickSlip Printed. Delete Not Allowed. (lsp_Pre_Delete_Wave_STD)'               
         GOTO EXIT_SP 
      END                         

      IF EXISTS(  SELECT 1
                  FROM TASKDETAIL TD WITH (NOLOCK)
                  WHERE TD.WaveKey = @c_WaveKey
                  AND TD.[Status] IN ('3','9')
               )
      BEGIN
         SET @n_continue = 3
         SET @n_err = 552353
         SET @c_errmsg = 'NSQL'+CONVERT(NVARCHAR(6),@n_err)
                        + ': Cannot delete this wave. The wave has task details which are In Progress and/or Completed and which may not be deleted'
                        + '. (lsp_Pre_Delete_Wave_STD)' 
         GOTO EXIT_SP 
      END  
      ELSE
      BEGIN
         SET @c_errmsg    = 'There are Task Details for this Wave. Delete Anyway?'
         GOTO EXIT_SP                                                                                                                                                                                                                   
      END                
   END TRY
   
   BEGIN CATCH
      SET @n_Continue = 3
      SET @c_ErrMsg = ERROR_MESSAGE()
      GOTO EXIT_SP
   END CATCH
   --(mingle01) - END 
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
      execute nsp_logerror @n_err, @c_errmsg, 'lsp_Pre_Delete_Wave_STD'
      RETURN  
   END  
   ELSE  
   BEGIN  
      SELECT @b_success = 1  
      WHILE @@TRANCOUNT > @n_starttcnt  
      BEGIN  
         COMMIT TRAN  
      END  
      RETURN  
   END              
END -- End Procedure

GO