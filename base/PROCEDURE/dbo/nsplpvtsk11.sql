SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*************************************************************************/  
/* Stored Procedure: nspLPVTSK11                                         */  
/* Creation Date: 18-AUG-2020                                            */  
/* Copyright: LFL                                                        */  
/* Written by: WLChooi                                                   */  
/*                                                                       */  
/* Purpose: WMS-14764 - CN_MAST_Rcm_release_pick_task - Reverse          */
/*                                                                       */  
/* Called By: Load                                                       */  
/*                                                                       */  
/* GitLab Version: 1.0                                                   */  
/*                                                                       */  
/* Version: 7.0                                                          */  
/*                                                                       */  
/* Data Modifications:                                                   */  
/*                                                                       */  
/* Updates:                                                              */  
/* Date         Author   Ver  Purposes                                   */  
/*************************************************************************/   

CREATE PROCEDURE [dbo].[nspLPVTSK11]      
    @c_loadkey      NVARCHAR(10)  
   ,@b_Success      INT            OUTPUT  
   ,@n_err          INT            OUTPUT  
   ,@c_errmsg       NVARCHAR(250)  OUTPUT  
AS  
BEGIN  
   SET NOCOUNT ON   
   SET QUOTED_IDENTIFIER OFF   
   SET ANSI_NULLS OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF  
    
   DECLARE @n_continue    INT,    
           @n_starttcnt   INT,         -- Holds the current transaction count  
           @n_debug       INT,
           @n_cnt         INT,
           @c_trmlogkey   NVARCHAR(10),
           @c_BatchNo     NVARCHAR(10),
           @c_Storerkey   NVARCHAR(15)
            
   SELECT  @n_starttcnt=@@TRANCOUNT , @n_continue=1, @b_success=0,@n_err=0,@c_errmsg='',@n_cnt=0
   SELECT  @n_debug = 0
   
   DECLARE  @c_Facility            NVARCHAR(5)
           ,@c_TaskType            NVARCHAR(10)            
           ,@c_SourceType          NVARCHAR(30)

   IF ISNULL(@c_Storerkey,'') = ''
   BEGIN
      SELECT @c_Storerkey = Storerkey
      FROM ORDERS (NOLOCK) 
      WHERE Loadkey = @c_LoadKey
   END

   CREATE TABLE #TEMP_TABLE (
      Loadkey      NVARCHAR(10) NULL,
      Orderkey     NVARCHAR(10) NULL,
      Pickslipno   NVARCHAR(10) NULL
   )
                           
   SET @c_SourceType = 'nspLPVTSK11'    

   INSERT INTO #TEMP_TABLE
   SELECT LPD.Loadkey, PD.Orderkey, PD.Pickslipno
   FROM PICKDETAIL PD (NOLOCK)
   JOIN ORDERS OH (NOLOCK) ON OH.Orderkey = PD.Orderkey
   JOIN LOADPLANDETAIL LPD (NOLOCK) ON LPD.Orderkey = OH.Orderkey
   WHERE LPD.Loadkey = @c_LoadKey

   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      DECLARE CUR_LOOP CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT DISTINCT Pickslipno
      FROM #TEMP_TABLE

      OPEN CUR_LOOP

      FETCH NEXT FROM CUR_LOOP INTO @c_BatchNo

      WHILE @@FETCH_STATUS <> -1
      BEGIN
         DELETE FROM Transmitlog2
         WHERE Key1 = @c_BatchNo
         AND Key2 = @c_LoadKey
         AND Key3 = @c_Storerkey
         AND TableName = 'WSPICKVCLOG'

         SET @n_err = @@ERROR
         IF @n_err <> 0    
         BEGIN  
            SELECT @n_continue = 3    
            SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 89025   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
            SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Delete Transmitlog2 Failed. (nspLPVTSK11)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '    
            GOTO QUIT_SP  
         END

         FETCH NEXT FROM CUR_LOOP INTO @c_BatchNo
      END
   END

QUIT_SP:
   IF CURSOR_STATUS('LOCAL', 'CUR_LOOP') IN (0 , 1)
   BEGIN
      CLOSE CUR_LOOP
      DEALLOCATE CUR_LOOP   
   END

   IF OBJECT_ID('tempdb..#TEMP_TABLE') IS NOT NULL
      DROP TABLE #TEMP_TABLE

   IF @n_continue=3  -- Error Occured - Process And Return  
   BEGIN  
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
      execute nsp_logerror @n_err, @c_errmsg, "nspLPVTSK11"  
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012  
      RETURN  
   END  
   ELSE  
   BEGIN  
      WHILE @@TRANCOUNT > @n_starttcnt  
      BEGIN  
         COMMIT TRAN  
      END  
      RETURN  
   END      
END --sp end

GO