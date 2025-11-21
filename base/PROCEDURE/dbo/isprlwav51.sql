SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: ispRLWAV51                                         */  
/* Creation Date: 17-May-2022                                           */
/* Copyright: LFL                                                       */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose: WMS-19646 - TBLSG Robot - WMS Release Wave (WMS & Geek+)    */ 
/*                                                                      */
/* Called By: Wave                                                      */ 
/*                                                                      */
/* GitLab Version: 1.0                                                  */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author   Ver  Purposes                                  */
/* 17-May-2022  WLChooi  1.0  DevOps Combine Script                     */
/************************************************************************/

CREATE PROCEDURE [dbo].[ispRLWAV51]      
       @c_Wavekey      NVARCHAR(10)  
     , @b_Success      INT            OUTPUT  
     , @n_err          INT            OUTPUT  
     , @c_errmsg       NVARCHAR(250)  OUTPUT  
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_Continue              INT
         , @b_Debug                 INT
         , @n_StartTranCnt          INT
         , @c_Storerkey             NVARCHAR(15)
         , @c_Facility              NVARCHAR(5)
         , @c_DocType               NVARCHAR(10)
         , @c_OrderGroup            NVARCHAR(20)
         , @c_Orderkey              NVARCHAR(10)
         , @c_ECSingleFlag          NVARCHAR(10)
         , @c_SUSR2                 NVARCHAR(20)
         , @c_TableName             NVARCHAR(20)
         , @c_GetSUSR2              NVARCHAR(20)
         , @c_SUSR2List             NVARCHAR(4000) = 'EXPORT, WHOLESALE, B2B (R), WHOLESALE (Z)'
         , @c_Key2                  NVARCHAR(50) = ''
         , @c_Pickslipno            NVARCHAR(10)
         , @c_Loadkey               NVARCHAR(10)

   DECLARE @c_PZone                 NVARCHAR(50)
         , @c_PrevLoadkey            NVARCHAR(50)
         , @c_PickDetailKey         NVARCHAR(10)
         , @c_ExecStatement         NVARCHAR(MAX)
         , @c_RPickslipno           NVARCHAR(10)
         , @c_OrdLineNo             NVARCHAR(5)
         , @c_GetWavekey            NVARCHAR(10)
         , @c_GetLoadkey            NVARCHAR(10)
         , @c_GetPHOrdKey           NVARCHAR(10)
         , @c_GetWDOrdKey           NVARCHAR(10)

   SET @b_Debug = @n_err
      
   SELECT @n_StartTranCnt = @@TRANCOUNT, @n_Continue = 1, @b_success = 1, @n_err = 0, @c_errmsg = ''

   -----Get Wave Info-----
   IF (@n_Continue = 1 OR @n_Continue = 2)
   BEGIN      
      SELECT @c_Storerkey     = MAX(OH.Storerkey)
           , @c_Facility      = MAX(OH.Facility)
           , @c_OrderGroup    = MAX(OH.OrderGroup)
           , @c_ECSingleFlag  = MAX(OH.ECOM_SINGLE_Flag)
           , @c_SUSR2         = MAX(ISNULL(ST.SUSR2,''))
      FROM WAVEDETAIL WD (NOLOCK)
      JOIN ORDERS OH (NOLOCK) ON OH.OrderKey = WD.OrderKey
      LEFT JOIN STORER ST (NOLOCK) ON ST.StorerKey = OH.ConsigneeKey 
                                  AND ST.ConsigneeFor = OH.StorerKey
      WHERE WD.WaveKey = @c_Wavekey      
      
      IF EXISTS (SELECT 1
                 FROM ORDERS OH (NOLOCK) 
                 JOIN WAVEDETAIL WD (NOLOCK) ON WD.OrderKey = OH.OrderKey
                 LEFT JOIN LOADPLANDETAIL LPD (NOLOCK) ON LPD.OrderKey = OH.OrderKey
                 WHERE WD.WaveKey = @c_Wavekey AND ISNULL(LPD.LoadKey,'') = '')
      BEGIN
         SELECT @n_continue = 3    
         SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 65554   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
         SELECT @c_errmsg = 'NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Some orders not yet generate Loadplan. (ispRLWAV51)' 
                          + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '    
         GOTO QUIT_SP 
      END
   END

   --Main Process
   IF (@n_Continue = 1 OR @n_Continue = 2)
   BEGIN   
      IF @c_OrderGroup = 'ECOM' AND @c_ECSingleFlag = 'S'
      BEGIN
         SET @c_TableName = 'WSWVOUTGK'

         EXEC dbo.ispGenTransmitLog2 @c_TableName     = @c_TableName,            
                                     @c_Key1          = @c_Wavekey,                 
                                     @c_Key2          = @c_OrderGroup,                 
                                     @c_Key3          = @c_Storerkey,                 
                                     @c_TransmitBatch = N'',        
                                     @b_Success       = @b_Success   OUTPUT,
                                     @n_err           = @n_err       OUTPUT,        
                                     @c_errmsg        = @c_errmsg    OUTPUT  
                                     
         IF @n_err <> 0
         BEGIN  
            SELECT @n_continue = 3    
            SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 65555   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
            SELECT @c_errmsg = 'NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Failed to EXEC ispGenTransmitLog2 (Tablename = WSWVOUTGK). (ispRLWAV51)' 
                             + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '    
            GOTO QUIT_SP  
         END

         --Generate Conso Pickheader and update Pickheaderkey = Pickdetail.Pickslipno
         SET @c_Orderkey = ''  
         SET @c_PrevLoadkey = ''
         SET @c_PickDetailKey = ''  
         SET @n_continue = 1
          
         DECLARE CUR_LOAD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
         SELECT DISTINCT LPD.Loadkey  
                       , PD.Orderkey 
                       , ''
                       , PD.PickDetailKey
         FROM PICKDETAIL PD (NOLOCK)
         JOIN LOC L (NOLOCK) ON L.LOC = PD.LOC
         JOIN ORDERS OH (NOLOCK) ON OH.OrderKey = PD.OrderKey
         JOIN LOADPLANDETAIL LPD (NOLOCK) ON LPD.OrderKey = OH.Orderkey
         LEFT JOIN RefKeyLookup RKL (NOLOCK) ON (RKL.PickDetailKey = PD.PickDetailKey) 
         JOIN WAVEDETAIL WD (NOLOCK) ON WD.OrderKey = OH.OrderKey
         WHERE ISNULL(RKL.PickSlipNo,'') = ''
         AND WD.WaveKey = @c_Wavekey
         ORDER BY PD.PickDetailKey        
         
         OPEN CUR_LOAD  
           
         FETCH NEXT FROM CUR_LOAD INTO @c_Loadkey,@c_Orderkey   
                                     , @c_PZone
                                     , @c_PickDetailKey
         
         WHILE (@@FETCH_STATUS <> -1)  
         BEGIN              
            IF ISNULL(@c_Orderkey, '0') = '0'  
               BREAK  
       
            IF @c_PrevLoadkey <> @c_Loadkey          
            BEGIN               
               SET @c_RPickSlipNo = ''
                
               EXECUTE nspg_GetKey       
                        'PICKSLIP'    
                     ,  9    
                     ,  @c_RPickSlipNo   OUTPUT    
                     ,  @b_Success       OUTPUT    
                     ,  @n_err           OUTPUT    
                     ,  @c_errmsg        OUTPUT 
                              
               IF @b_success = 1   
               BEGIN                 
                  SET @c_RPickSlipNo = 'P' + @c_RPickSlipNo          
                             
                  INSERT INTO PICKHEADER      
                           (  PickHeaderKey    
                           ,  Wavekey    
                           ,  Orderkey    
                           ,  ExternOrderkey    
                           ,  Loadkey    
                           ,  PickType    
                           ,  Zone    
                           ,  consoorderkey
                           ,  TrafficCop    
                           )      
                  VALUES      
                           (  @c_RPickSlipNo    
                           ,  @c_Wavekey     
                           ,  '' 
                           ,  @c_RPickSlipNo   
                           ,  @c_Loadkey    
                           ,  '0'     
                           ,  'LP'  
                           ,  @c_PZone     
                           ,  ''    
                           )          
                  
                  SET @n_err = @@ERROR
                        
                  IF @n_err <> 0      
                  BEGIN      
                     SET @n_continue = 3      
                     SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)    
                     SET @n_err = 81008  -- Should Be Set To The SQL Errmessage but I don't know how to do so.      
                     SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert PICKHEADER Failed (ispRLWAV51)'   
                                  + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '   
                     GOTO QUIT_SP     
                  END                 
               END
               ELSE   
               BEGIN  
                  SELECT @n_continue = 3  
                  SELECT @n_err = 63502
                  SELECT @c_errmsg = 'NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Get PSNO Failed. (ispRLWAV51)'  
                  BREAK   
               END            
            END            
              
            IF @n_Continue = 1  
            BEGIN        
               SET @c_ExecStatement = N'DECLARE C_PickDetailKey CURSOR FAST_FORWARD READ_ONLY FOR ' +
                                      'SELECT PickDetail.PickDetailKey, PickDetail.OrderLineNumber ' +   
                                      'FROM PickDetail WITH (NOLOCK) ' +
                                      'JOIN OrderDetail WITH (NOLOCK) ' +                                       
                                      'ON (PICKDETAIL.OrderKey = ORDERDETAIL.OrderKey AND ' + 
                                      'PICKDETAIL.OrderLineNumber = ORDERDETAIL.OrderLineNumber) ' +
                                      'JOIN LOC WITH (NOLOCK) ON (PICKDETAIL.Loc = LOC.Loc) ' +
                                      'WHERE PickDetail.pickdetailkey = ''' + @c_PickDetailKey + '''' +
                                      ' AND OrderDetail.LoadKey  = ''' + @c_Loadkey  + ''' ' +
                                      --' AND LOC.PutawayZone = ''' + RTRIM(@c_Pzone) + ''' ' +  
                                      ' ORDER BY PickDetail.PickDetailKey '  
         
               EXEC(@c_ExecStatement)
               OPEN C_PickDetailKey  
               
               FETCH NEXT FROM C_PickDetailKey INTO @c_PickDetailKey, @c_OrdLineNo   
           
               WHILE @@FETCH_STATUS <> -1  
               BEGIN  
                  IF NOT EXISTS (SELECT 1 FROM RefKeyLookup WITH (NOLOCK) WHERE PickDetailKey = @c_PickDetailKey)   
                  BEGIN   
                     INSERT INTO RefKeyLookup (PickDetailkey, Pickslipno, OrderKey, OrderLineNumber, Loadkey)  
                     VALUES (@c_PickDetailKey, @c_RPickSlipNo, @c_Orderkey, @c_OrdLineNo, @c_Loadkey)
         
                     SELECT @n_err = @@ERROR  
                     IF @n_err <> 0   
                     BEGIN  
                        SELECT @n_continue = 3
                        SELECT @n_err = 63503
                        SELECT @c_errmsg = 'NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert RefKeyLookup Failed. (ispRLWAV51)'    
                        GOTO QUIT_SP
                     END                          
                  END   
           
                  FETCH NEXT FROM C_PickDetailKey INTO @c_PickDetailKey, @c_OrdLineNo   
              END   
              CLOSE C_PickDetailKey   
              DEALLOCATE C_PickDetailKey        
           END   
           
           UPDATE PICKDETAIL WITH (ROWLOCK)      
           SET PickSlipNo = @c_RPickSlipNo     
              ,EditWho = SUSER_NAME()    
              ,EditDate= GETDATE()     
              ,TrafficCop = NULL     
           FROM ORDERS     OH WITH (NOLOCK)    
           JOIN PICKDETAIL PD ON (OH.Orderkey = PD.Orderkey) 
           JOIN LOC L ON L.LOC = PD.Loc   
           WHERE PD.OrderKey = @c_Orderkey  
           --AND L.PutawayZone = @c_PZone
           AND ISNULL(PickSlipNo,'') = ''  
           AND Pickdetailkey = @c_PickDetailKey
           
           SET @n_err = @@ERROR      
           
           IF @n_err <> 0      
           BEGIN      
                SET @n_continue = 3      
                SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)    
                SET @n_err = 81009 -- Should Be Set To The SQL Errmessage but I don't know how to do so.      
                SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': UPDATE Pickdetail Failed (ispRLWAV51)'   
                             + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '   
                GOTO QUIT_SP     
           END  

           SET @c_PrevLoadkey = @c_Loadkey                 
                   
           FETCH NEXT FROM CUR_LOAD INTO @c_Loadkey,@c_Orderkey  
                                       , @c_PZone
                                       , @c_PickDetailKey
         END  
         CLOSE CUR_LOAD  
         DEALLOCATE CUR_LOAD  

         SET @c_Loadkey = ''
         SET @c_Orderkey = ''
         SET @c_PZone = ''
         SET @c_PickDetailKey = ''
         
         DECLARE CUR_WaveOrder CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
            SELECT DISTINCT   
                   WD.Wavekey  
                  ,LPD.LoadKey  
                  ,''
                  ,WD.Orderkey
            FROM WAVEDETAIL      WD  WITH (NOLOCK)  
            JOIN LOADPLANDETAIL  LPD WITH (NOLOCK) ON (WD.Orderkey = LPD.Orderkey)  
            JOIN PICKDETAIL AS PDET ON PDET.OrderKey = WD.OrderKey
            JOIN LOC L WITH (NOLOCK) ON L.LOC = PDET.Loc
            WHERE WD.WaveKey = @c_Wavekey                                        
                                                
         OPEN CUR_WaveOrder 
         
         FETCH NEXT FROM CUR_WaveOrder INTO @c_GetWavekey, @c_GetLoadkey, @c_GetPHOrdKey, @c_GetWDOrdKey
         
         WHILE (@@FETCH_STATUS <> -1)  
         BEGIN            
             IF NOT EXISTS (SELECT 1 FROM PICKHEADER (NOLOCK)
                            WHERE Wavekey      = @c_Wavekey 
                            AND Orderkey       = @c_GetWDOrdKey)         
             BEGIN               
                BEGIN TRAN
                EXECUTE nspg_GetKey       
                         'PICKSLIP'    
                      ,  9    
                      ,  @c_Pickslipno OUTPUT    
                      ,  @b_Success    OUTPUT    
                      ,  @n_err        OUTPUT    
                      ,  @c_errmsg     OUTPUT          
                                 
                SET @c_Pickslipno = 'P' + @c_Pickslipno    

                INSERT INTO PICKHEADER      
                         (  PickHeaderKey    
                         ,  Wavekey    
                         ,  Orderkey    
                         ,  ExternOrderkey    
                         ,  Loadkey    
                         ,  PickType    
                         ,  Zone    
                         ,  consoorderkey
                         ,  TrafficCop    
                         )      
                VALUES      
                         (  @c_Pickslipno    
                         ,  @c_Wavekey    
                         ,  @c_GetWDOrdKey   
                         ,  @c_Pickslipno   
                         ,  @c_GetLoadkey    
                         ,  '0'     
                         ,  '3'  
                         ,  ''  
                         ,  ''    
                         )          
                 
                SET @n_err = @@ERROR      
                
                IF @n_err <> 0      
                BEGIN      
                     SET @n_continue = 3      
                     SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)    
                     SET @n_err = 81008  -- Should Be Set To The SQL Errmessage but I don't know how to do so.      
                     SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert PICKHEADER Failed (ispRLWAV51)'   
                                  + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '   
                     GOTO QUIT_SP     
                END      
             END   
           
            FETCH NEXT FROM CUR_WaveOrder INTO @c_GetWavekey, @c_GetLoadkey, @c_GetPHOrdKey, @c_GetWDOrdKey
         END     
         CLOSE CUR_WaveOrder  
         DEALLOCATE CUR_WaveOrder  
      END
      ELSE
      BEGIN
         DECLARE CUR_LOOP CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT DISTINCT OH.Orderkey, ST.SUSR2, OH.OrderGroup, OH.ECOM_SINGLE_Flag
            FROM WAVEDETAIL WD (NOLOCK)
            JOIN ORDERS OH (NOLOCK) ON OH.OrderKey = WD.OrderKey
            LEFT JOIN STORER ST (NOLOCK) ON ST.StorerKey = OH.ConsigneeKey 
                                        AND ST.ConsigneeFor = OH.StorerKey
            WHERE WD.WaveKey = @c_Wavekey 
            ORDER BY OH.OrderKey

         OPEN CUR_LOOP

         FETCH NEXT FROM CUR_LOOP INTO @c_Orderkey, @c_GetSUSR2, @c_OrderGroup, @c_ECSingleFlag

         WHILE @@FETCH_STATUS <> -1
         BEGIN
            SET @c_Key2 = ''
            
            IF EXISTS (SELECT 1
                       FROM dbo.fnc_DelimSplit(',', @c_SUSR2List) FDS
                       WHERE TRIM(FDS.ColValue) = @c_GetSUSR2)
            BEGIN
               SET @c_Key2 = @c_GetSUSR2
            END
            
            IF @c_OrderGroup = 'ECOM' AND @c_ECSingleFlag = 'M'
            BEGIN
               SET @c_Key2 = @c_OrderGroup
            END
            
            IF @c_Key2 = ''
            BEGIN
               GOTO NEXT_LOOP
            END

            SET @c_TableName = 'WSSOOUTGK'

            EXEC dbo.ispGenTransmitLog2 @c_TableName     = @c_TableName,            
                                        @c_Key1          = @c_Orderkey,                 
                                        @c_Key2          = @c_Key2,                 
                                        @c_Key3          = @c_Storerkey,                 
                                        @c_TransmitBatch = N'',        
                                        @b_Success       = @b_Success   OUTPUT,
                                        @n_err           = @n_err       OUTPUT,        
                                        @c_errmsg        = @c_errmsg    OUTPUT  
            
            IF @n_err <> 0
            BEGIN  
               SELECT @n_continue = 3    
               SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 65560   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
               SELECT @c_errmsg = 'NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Failed to EXEC ispGenTransmitLog2 (Tablename = WSSOOUTGK). (ispRLWAV51)' 
                                + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '    
               GOTO QUIT_SP  
            END

            --Generate Discrete Pickheader and update Pickheaderkey = Pickdetail.Pickslipno
            SET @c_Pickslipno = ''

            IF (@n_Continue = 1 OR @n_Continue = 2)
            BEGIN
               EXEC dbo.isp_CreatePickSlip @c_Orderkey = @c_Orderkey
                                         , @c_PickslipType = N'3'        
                                         , @c_ConsolidateByLoad = N'N'   
                                         , @c_LinkPickSlipToPick = N'Y'  
                                         , @c_AutoScanIn = N'N'          
                                         , @b_Success = @b_Success   OUTPUT
                                         , @n_Err = @n_Err           OUTPUT        
                                         , @c_ErrMsg = @c_ErrMsg     OUTPUT  
               IF @n_err <> 0
               BEGIN  
                  SELECT @n_continue = 3    
                  SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 65561   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
                  SELECT @c_errmsg = 'NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Failed to EXEC isp_CreatePickSlip. (ispRLWAV51)' 
                                   + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '    
                  GOTO QUIT_SP  
               END

               SELECT @c_Pickslipno = PH.PickHeaderKey 
                    , @c_Loadkey    = LPD.LoadKey
               FROM PICKHEADER PH (NOLOCK)
               JOIN LOADPLANDETAIL LPD (NOLOCK) ON PH.OrderKey = LPD.OrderKey
               WHERE PH.Orderkey = @c_Orderkey
               
               UPDATE dbo.PICKHEADER
               SET ExternOrderKey = @c_Loadkey
               WHERE PickHeaderKey = @c_Pickslipno
            END

            NEXT_LOOP:
            FETCH NEXT FROM CUR_LOOP INTO @c_Orderkey, @c_GetSUSR2, @c_OrderGroup, @c_ECSingleFlag
         END
         CLOSE CUR_LOOP
         DEALLOCATE CUR_LOOP
      END
   END

   QUIT_SP:

   IF (SELECT CURSOR_STATUS('LOCAL','CUR_LOOP')) >=0 
   BEGIN
      CLOSE CUR_LOOP           
      DEALLOCATE CUR_LOOP      
   END  

   IF (SELECT CURSOR_STATUS('LOCAL','CUR_LOAD')) >=0 
   BEGIN
      CLOSE CUR_LOAD           
      DEALLOCATE CUR_LOAD      
   END
   
   IF (SELECT CURSOR_STATUS('LOCAL','CUR_WaveOrder')) >=0 
   BEGIN
      CLOSE CUR_WaveOrder           
      DEALLOCATE CUR_WaveOrder      
   END  

   IF @n_Continue = 3  -- Error Occured - Process And Return
   BEGIN
      SELECT @b_success = 0
      IF @@TRANCOUNT = 1 and @@TRANCOUNT > @n_StartTranCnt
      BEGIN
         ROLLBACK TRAN
      END
      ELSE
      BEGIN
         WHILE @@TRANCOUNT > @n_StartTranCnt
         BEGIN
            COMMIT TRAN
         END
      END
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'ispRLWAV51'
      --RAISERROR @n_err @c_errmsg
      RETURN
   END
   ELSE
   BEGIN
      SELECT @b_success = 1
      WHILE @@TRANCOUNT > @n_StartTranCnt
      BEGIN
         COMMIT TRAN
      END
      RETURN
   END
END

GO