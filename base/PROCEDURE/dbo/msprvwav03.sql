SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*************************************************************************/    
/* Stored Procedure: mspRVWAV03                                          */    
/* Creation Date: 2024-05-15                                             */
/* Copyright: Maersk                                                     */    
/* Written by: Shong                                                     */    
/*                                                                       */    
/* Purpose: UWP-18747 - Cancel Levis US MPOC and Cartonization           */  
/*                                                                       */  
/*                                                                       */    
/* Called By: Wave Release                                               */    
/*                                                                       */    
/* PVCS Version: 1.1                                                     */    
/*                                                                       */    
/* Version: 7.0                                                          */    
/*                                                                       */    
/* Data Modifications:                                                   */    
/*                                                                       */    
/* Updates:                                                              */    
/* Date        Author   Ver   Purposes                                   */
/* 2024-11-25  Wan01    1.1   UWP-27137 - [FCR-1348] [Levi's] Levi's Wave*/
/*                            Release (Automation and Manual Operations) */
/*************************************************************************/     
CREATE   PROCEDURE [dbo].[mspRVWAV03]        
 @c_wavekey      NVARCHAR(10) 
,@c_Orderkey     NVARCHAR(10) = ''     
,@b_Success      INT             OUTPUT    
,@n_err          INT             OUTPUT    
,@c_errmsg       NVARCHAR(250)   OUTPUT    
AS    
BEGIN    
   SET NOCOUNT ON     
   SET QUOTED_IDENTIFIER OFF     
   SET ANSI_NULLS OFF     
   SET CONCAT_NULL_YIELDS_NULL OFF    
      
   DECLARE @n_continue       INT = 1      
         , @n_starttcnt      INT = @@TRANCOUNT        -- Holds the current transaction count    
         , @n_debug          INT = 0  
         , @n_cnt            INT = 0  
         , @c_otherwavekey   NVARCHAR(10) = '' 
         , @c_TaskType       NVARCHAR(10) = 'ASTCPK'
         , @n_AllowToRev     INT          = 0  
         , @c_Storerkey      NVARCHAR(15) = '' 
         , @c_facility       NVARCHAR(5)  = ''  
         , @c_Taskdetailkey  NVARCHAR(10) = '' 
         , @c_PickDetailKey  NVARCHAR(10) = '' 
         , @c_PickSlipNo     NVARCHAR(10) = '' 
         , @c_authority      NVARCHAR(10) = '' 
         , @c_SourceType     NVARCHAR(30) = 'mspRLWAV03'
         , @c_Automation     NVARCHAR(10) = ''                                   --(Wan01)

         , @CUR_DELTASK      CURSOR
         , @CUR_DELPICK      CURSOR
         , @CUR_DELPRECARTON CURSOR
         , @CUR_UPDATEORD    CURSOR                                              --(Wan01)
                     
   SET @b_success=0
   SET @n_err=0
   SET @c_errmsg=''
   SET @n_cnt=0  

   SELECT @c_Automation = ISNULL(w.Userdefine09,'')                                 --(Wan01)
   FROM WAVE w (NOLOCK)
   WHERE w.Wavekey = @c_WaveKey

   -----Get Storerkey and facility 
   SELECT TOP 1 @c_StorerKey = O.Storerkey,  
               @c_Facility = O.Facility   
   FROM WAVEDETAIL WD (NOLOCK)  
   JOIN ORDERS O (NOLOCK) ON (WD.Orderkey = O.Orderkey)  
   WHERE WD.Wavekey = @c_Wavekey    
  
   ----reject if wave not yet release        
   IF @n_continue = 1 OR @n_continue = 2  
   BEGIN  
      IF NOT EXISTS (SELECT 1 FROM TASKDETAIL TD (NOLOCK)   
                     WHERE TD.Wavekey = @c_Wavekey AND TD.SourceType = @c_SourceType
                     AND TD.TaskType IN ('ASTCPK','FCP', 'RPF'))                    --(Wan01)  
      BEGIN                                            
         SET @n_continue = 3    
         SET @n_err = 81010    
         SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': This Wave has not been released. (mspRVWAV03)'           
      END                   
   END  
 
   ----reject if any task was started  
   IF @n_continue = 1 OR @n_continue = 2  
   BEGIN 
      SET @n_AllowToRev = 1   
      SELECT TOP 1 @n_AllowToRev = CASE WHEN @c_Automation <> 'Y' AND TD.[Status] IN ('0')   --(Wan01)
                                        THEN 1
                                        ELSE 0
                                        END
      FROM TASKDETAIL TD (NOLOCK)   
      WHERE TD.Wavekey = @c_Wavekey  
      AND  TD.Sourcetype = @c_SourceType
      AND  TD.TaskType IN (@c_TaskType,'FCP','RPF')                                 --(Wan01)
      AND  TD.[Status] NOT IN ('X','H')                                             --(Wan01)
      ORDER BY 1                                                                    --(Wan01)

      IF @n_AllowToRev = 0                                                          --(Wan01)
      BEGIN  
          SET @n_continue = 3    
          SET @n_err = 81020    
          SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Some Tasks have been started. Not allow to Reverse Wave Released (mspRVWAV03)'         
      END                   
   END  

   IF @n_continue = 1 OR @n_continue = 2  
   BEGIN  
      IF EXISTS (SELECT 1 FROM dbo.PICKDETAIL PD (NOLOCK)   
                     WHERE PD.Wavekey = @c_Wavekey 
                     AND PD.Status = '5')  
      BEGIN                                            
         SET @n_continue = 3    
         SET @n_err = 81030    
         SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Pick Tasks have been started. Not allow to Reverse Wave Released (mspRVWAV03)'           
      END                   
   END  
   
   BEGIN TRAN  
   ----Delete Pre-Cartonization
   IF @n_continue = 1 OR @n_continue = 2  
   BEGIN
      SET @CUR_DELPRECARTON = CURSOR FAST_FORWARD READ_ONLY FOR
      SELECT PH.PickSlipNo  
      FROM dbo.PackHeader PH WITH (NOLOCK) 
      JOIN dbo.WAVEDETAIL WD WITH (NOLOCK) ON WD.OrderKey = PH.OrderKey
      WHERE WD.Wavekey = @c_Wavekey  
      AND  PH.[Status] ='0'
      ORDER BY PH.PickSlipNo 

      OPEN @CUR_DELPRECARTON

      FETCH NEXT FROM @CUR_DELPRECARTON INTO @c_PickSlipNo

      WHILE @@FETCH_STATUS = 0 AND @c_PickSlipNo <> '' AND @n_Continue = 1
      BEGIN
         DELETE dbo.PackDetail
         WHERE PickSlipNo = @c_PickSlipNo

         SET @n_err = @@ERROR  
         IF @n_err <> 0   
         BEGIN  
            SET @n_continue = 3    
            SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)
            SET @n_err = 562251   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
            SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(6),@n_err)+': Delete PackDetail Table Failed. (mspRVWAV03)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '    
         END 

         DELETE dbo.PackInfo
         WHERE PickSlipNo = @c_PickSlipNo

         SET @n_err = @@ERROR  
         IF @n_err <> 0   
         BEGIN  
            SET @n_continue = 3    
            SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)
            SET @n_err = 562252   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
            SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(6),@n_err)+': Delete PackInfo Table Failed. (mspRVWAV03)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '    
         END 

         DELETE dbo.PackHeader
         WHERE PickSlipNo = @c_PickSlipNo

         SET @n_err = @@ERROR  
         IF @n_err <> 0   
         BEGIN  
            SET @n_continue = 3    
            SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)
            SET @n_err = 562253   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
            SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(6),@n_err)+': Delete PackHeader Table Failed. (mspRVWAV03)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '    
         END 

         FETCH NEXT FROM @CUR_DELPRECARTON INTO @c_PickSlipNo
      END
      CLOSE @CUR_DELPRECARTON
      DEALLOCATE @CUR_DELPRECARTON
   END      

   ----delete tasks  
   IF @n_continue = 1 OR @n_continue = 2  
   BEGIN 
      SET @CUR_DELTASK = CURSOR FAST_FORWARD READ_ONLY FOR
      SELECT TaskDetailKey = CASE WHEN @c_Automation = 'Y' AND 
                                       TD.TaskType IN (@c_TaskType, 'FCP','RPF') AND TD.[Status] IN ('X','H')  --(Wan01)
                                  THEN TD.TaskDetailkey
                                  WHEN @c_Automation <> 'Y' AND                                                --(Wan01)                     
                                       TD.TaskType = @c_TaskType AND TD.[Status] IN ('0','X','H')                     
                                  THEN TD.TaskDetailkey
                                  ELSE ''
                                  END
      FROM TASKDETAIL TD (NOLOCK)   
      WHERE TD.Wavekey = @c_Wavekey  
      AND  TD.Sourcetype = @c_SourceType 
      AND  TD.TaskType IN (@c_TaskType,'FCP', 'RPF')                                 --(Wan01)
      AND  TD.[Status] IN ('0','X','H')                                              --(Wan01)
      ORDER BY 1 DESC

      OPEN @CUR_DELTASK

      FETCH NEXT FROM @CUR_DELTASK INTO @c_TaskDetailKey

      WHILE @@FETCH_STATUS = 0 AND @c_TaskDetailKey <> '' AND @n_Continue = 1
      BEGIN
         DELETE TASKDETAIL  
         WHERE TASKDETAIL.TaskDetailKey = @c_TaskDetailKey   
         AND TASKDETAIL.Sourcetype = @c_SourceType 
         AND TASKDETAIL.TaskType IN (@c_TaskType,'FCP', 'RPF')                      --(Wan01)
         AND TASKDETAIL.Status IN ('0','X','H') 
           
         SET @n_err = @@ERROR  
         IF @n_err <> 0   
         BEGIN  
            SET @n_continue = 3    
            SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)
            SET @n_err = 562254   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
            SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(6),@n_err)+': Delete Taskdetail Table Failed. (mspRVWAV03)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '    
         END 
         FETCH NEXT FROM @CUR_DELTASK INTO @c_TaskDetailKey
      END
      CLOSE @CUR_DELTASK
      DEALLOCATE @CUR_DELTASK
   END  
            
   ----Remove taskdetailkey from pickdetail of the wave  
   IF @n_continue = 1 OR @n_continue = 2  
   BEGIN 
      SET @CUR_DELPICK = CURSOR FAST_FORWARD READ_ONLY FOR
      SELECT PickDetailKey = PICKDETAIL.PickDetailKey
      FROM WAVEDETAIL (NOLOCK)    
      JOIN PICKDETAIL (NOLOCK) ON WAVEDETAIL.Orderkey = PICKDETAIL.Orderkey
      WHERE WAVEDETAIL.Wavekey = @c_Wavekey
      ORDER BY PICKDETAIL.PickDetailKey

      OPEN @CUR_DELPICK

      FETCH NEXT FROM @CUR_DELPICK INTO @c_PickDetailKey

      WHILE @@FETCH_STATUS = 0 AND @c_PickDetailKey <> '' AND @n_Continue = 1
      BEGIN
         UPDATE PICKDETAIL WITH (ROWLOCK)   
            SET PICKDETAIL.TaskdetailKey = ''   
               ,CaseID= CASE WHEN @c_Automation = 'Y' AND L.Locationtype = 'PICKWCS' AND           --(Wan01) CR 1.9
                                  PICKDETAIL.UOM = '6' AND PICKDETAIL.PickMethod = '3' AND 
                                  LEFT(PICKDETAIL.CaseID,1) = 'T'
                             THEN ''
                             ELSE PICKDETAIL.DropId
                             END
               ,DROPID= CASE WHEN @c_Automation = 'Y' AND L.Locationtype = 'PICKWCS' AND           --(Wan01) 
                                  PICKDETAIL.UOM = '6' AND PICKDETAIL.PickMethod = '3' AND 
                                  LEFT(PICKDETAIL.DropID,1) = 'T'
                             THEN ''
                             ELSE PICKDETAIL.DropId
                             END
               ,TrafficCop = NULL   
         FROM PICKDETAIL                                                                           --(Wan01) 
         JOIN LOC l (NOLOCK) ON l.loc = PICKDETAIL.Loc                                             --(Wan01)    
         WHERE PICKDETAIL.PickDetailKey = @c_PickDetailKey   
           
         SET @n_err = @@ERROR  
         IF @n_err <> 0   
         BEGIN  
            SET @n_continue = 3    
            SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)
            SET @n_err = 562255   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
            SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(6),@n_err)+': Update Pickdetail Table Failed. (mspRVWAV03)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '    
         END 
         FETCH NEXT FROM @CUR_DELPICK INTO @c_PickDetailKey
      END
      CLOSE @CUR_DELPICK
      DEALLOCATE @CUR_DELPICK
   END  
   
   --Reverse Orders ContainerQty
   IF @n_continue = 1 or @n_continue = 2 AND @c_Automation = 'Y'                    --(Wan01) - START   
   BEGIN  
      SET @CUR_UPDATEORD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
      SELECT WD.Orderkey 
      FROM WAVEDETAIL WD (NOLOCK)  
      WHERE WD.Wavekey = @c_Wavekey 
      ORDER BY WD.WavedetailKey 

      OPEN @CUR_UPDATEORD
              
      FETCH NEXT FROM @CUR_UPDATEORD INTO @c_OrderKey
      
      WHILE @@FETCH_STATUS = 0 AND @n_Continue IN (1,2)
      BEGIN
         UPDATE ORDERS WITH (ROWLOCK)
            SET ContainerQty = 0
               ,EditDate = GETDATE()
               ,TrafficCop = NULL
         WHERE Orderkey = @c_Orderkey

         IF @@ERROR <> 0
         BEGIN
            SET @n_Continue = 3
            Set @n_Err = 81040
            SET @c_ErrMsg = 'NSQL'+CONVERT(CHAR(5) ,@n_err) + ': Updating Orders Failed (mspRLWAV03)'  
                          + ' ( '+' SQLSvr MESSAGE= ' + @c_ErrMsg + ' ) '
         END

         FETCH NEXT FROM @CUR_UPDATEORD INTO @c_OrderKey
      END
      CLOSE @CUR_UPDATEORD
      DEALLOCATE @CUR_UPDATEORD
   END                                                                              --(Wan01) - END  
   -----Reverse wave status------  
   IF @n_continue = 1 or @n_continue = 2    
   BEGIN    
      UPDATE WAVE   
         SET TMReleaseFlag = 'N'                
          ,  TrafficCop = NULL                  
          ,  EditWho = SUSER_SNAME()            
          ,  EditDate= GETDATE()                 
      WHERE WAVEKEY = @c_wavekey                
      SELECT @n_err = @@ERROR    
      IF @n_err <> 0    
      BEGIN    
         SET @n_continue = 3    
         SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)
         SET @n_err = 562256   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
         SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(6),@n_err)+': Update on wave Failed (mspRVWAV03)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '    
      END    
   END    
      
   -------Reverse SOStatus---------  
   --IF @n_continue = 1 or @n_continue = 2    
   --BEGIN    
   --   EXECUTE nspGetRight   
   --      @c_facility,    
   --      @c_StorerKey,                
   --      '', --sku  
   --      'UpdateSOReleaseTaskStatus', -- Configkey  
   --      @b_success    OUTPUT,  
   --      @c_authority  OUTPUT,  
   --      @n_err        OUTPUT,  
   --      @c_errmsg     OUTPUT        
  
   --   IF @b_success = 1 AND @c_authority = '1'   
   --   BEGIN  
   --      UPDATE ORDERS WITH (ROWLOCK)  
   --      SET SOStatus = '0',  
   --         TrafficCop = NULL,  
   --         EditWho = SUSER_SNAME(),  
   --         EditDate = GETDATE()  
   --      WHERE Userdefine09 = @c_Wavekey  
   --      AND SOStatus = 'TSRELEASED'  
   --   END            
   --END  
RETURN_SP:  
   IF @n_continue=3  -- Error Occured - Process And Return    
   BEGIN    
      SET @b_success = 0    
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
      execute nsp_logerror @n_err, @c_errmsg, "mspRVWAV03"    
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012    
      RETURN    
   END    
   ELSE    
   BEGIN    
      SET @b_success = 1    
      WHILE @@TRANCOUNT > @n_starttcnt    
      BEGIN    
         COMMIT TRAN    
      END    
      RETURN    
   END       
END --sp end  

GO