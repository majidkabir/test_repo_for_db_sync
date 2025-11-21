SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: isp_CreatePickSlip                                 */
/* Creation Date: 29-Sep-2017                                           */
/* Copyright: LFL                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: Create Pickslip                                             */   
/*          Discrete '8', '3', 'D'                                      */     
/*                    std(3) by orderkey (pickheader.orderkey)          */
/*          Conso '5','6','7','9','C'                                   */
/*                 std(5)  by loadkey (pickheader.externorderkey)       */
/*          Xdock 'XD','LB','LP' (refer to refkeylookup)                */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 6.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */  
/* Date         Author   Ver  Purposes                                  */  
/* 29-OCT-2019  CSCHONG  1.0  Fix deadlock issue (CS01)                 */
/* 21-Sep-2022  TLTING01 1.1  Performance tune                          */  
/* 23-Sep-2022  Wan01    1.1  Performance tune-BULK Update ON PICKDETAIL*/
/************************************************************************/

CREATE PROC [dbo].[isp_CreatePickSlip]   
    @c_Orderkey              NVARCHAR(10)  = ''       
   ,@c_Loadkey               NVARCHAR(10)  = ''   --Create discrete or conso load determine by @c_ConsolidateByLoad setting
   ,@c_Wavekey               NVARCHAR(10)  = ''   --Create discrete or conso load of the wave determine by @c_ConsolidateByLoad setting   
   ,@c_PickslipType          NVARCHAR(10)  = ''   --Discrete('8', '3', 'D')  Conso('5','6','7','9','C')  Xdock ('XD','LB','LP')
   ,@c_ConsolidateByLoad     NVARCHAR(5)   = 'N'   --Y=Create load consolidate pickslip  N=create discrete pickslip
   ,@c_Refkeylookup          NVARCHAR(5)   = 'N'   --Y=Create refkeylookup records  N=Not create
   ,@c_LinkPickSlipToPick    NVARCHAR(5)   = 'N'   --Y=Update pickslipno to pickdetail.pickslipno  N=Not update to pickdetail
   ,@c_AutoScanIn            NVARCHAR(5)   = 'N'   --Y=Auto scan in the pickslip N=Not auto scan in                                            
   ,@b_Success               INT  = 1            OUTPUT
   ,@n_Err                   INT  = 0            OUTPUT 
   ,@c_ErrMsg                NVARCHAR(250) = ''  OUTPUT
AS   
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF   
   SET ANSI_NULLS OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF  
     
   DECLARE @n_Continue           INT,
           @n_Cnt                INT,
           @n_StartTCnt          INT,
           @c_PickslipNo         NVARCHAR(10),
           @c_Storerkey          NVARCHAR(15),
         @c_GetPickOrderkey    NVARCHAR(20),  --(CS01)
         @c_PickDetailKey      NVARCHAR(20)   --(CS01)
   DECLARE @c_LD_PickDetailKey   NVARCHAR(10)
   
   DECLARE @CUR_UPD_PD           CURSOR               --(Wan01)
                                                                                                                 
    SELECT @n_Continue = 1, @n_StartTCnt = @@TRANCOUNT, @n_Err = 0, @c_ErrMsg = '', @b_Success = 1
    
    --Get storerkey
    IF @n_continue IN(1,2)
    BEGIN     
       IF ISNULL(@c_Orderkey,'') <> ''     
          SELECT @c_Storerkey = Storerkey
          FROM ORDERS (NOLOCK)
          WHERE Orderkey = @c_Orderkey
       ELSE IF  ISNULL(@c_Loadkey,'') <> ''
          SELECT TOP 1 @c_Storerkey = ORDERS.Storerkey
          FROM ORDERS (NOLOCK)
          JOIN Loadplandetail LD (NOLOCK) ON LD.Orderkey = ORDERS.Orderkey  -- tlting01
          WHERE LD.Loadkey = @c_Loadkey
       ELSE IF ISNULL(@c_Wavekey,'') <> '' 
          SELECT TOP 1 @c_Storerkey = ORDERS.Storerkey
        FROM ORDERS (NOLOCK)
         JOIN wavedetail WD (NOLOCK)  ON WD.Orderkey = ORDERS.Orderkey    -- tlting01
         WHERE WD.wavekey = @c_Wavekey
   END       
            
    --Check and Set default pickslip type if not provide
    IF @n_continue IN(1,2)
    BEGIN     
        IF ISNULL(@c_Picksliptype,'') = ''   
        BEGIN
          IF ISNULL(@c_Orderkey,'') <> ''     --have orderkey discrete
             SET @c_Picksliptype = '3'
          ELSE IF (ISNULL(@c_Wavekey,'') <> '' OR ISNULL(@c_Loadkey,'') <> '') AND @c_ConsolidateByLoad = 'Y' --have loadkey/Wavekey and conso by load
             SET @c_Picksliptype = '5'     
          ELSE IF (ISNULL(@c_Wavekey,'') <> '' OR ISNULL(@c_Loadkey,'') <> '') AND @c_ConsolidateByLoad <> 'Y' --have loadkey/wavekey and discrete
             SET @c_Picksliptype = '3'     
          ELSE 
             SET @c_Picksliptype = '3'     
       END         
   END
    
    --Generate discrete or conso pickslip by order/load/wave. Optionally update pickslip to pick or create refkeylookup
   IF @n_continue IN(1,2)         
   BEGIN
      IF ISNULL(@c_Orderkey,'') <> ''  --create discrete pickslip
      BEGIN
         SELECT @c_Pickslipno = ''
         
         SELECT @c_Pickslipno = Pickheaderkey
         FROM PICKHEADER(NOLOCK)
         WHERE Orderkey = @c_Orderkey
         
          IF ISNULL(@c_Pickslipno,'') = ''
          BEGIN            
            EXECUTE nspg_GetKey 'PICKSLIP',   9,   @c_Pickslipno OUTPUT,   @b_Success OUTPUT,   @n_err OUTPUT,   @c_errmsg OUTPUT                      
            SELECT @c_Pickslipno = 'P' + @c_Pickslipno      
            
            INSERT INTO PICKHEADER (PickHeaderKey, ExternOrderKey, Orderkey, PickType, Zone, Storerkey)  
                     VALUES (@c_Pickslipno , '', @c_Orderkey, '0', @c_PickslipType, @c_Storerkey)              
              
            SELECT @n_err = @@ERROR  
            IF @n_err <> 0  
            BEGIN  
               SELECT @n_continue = 3  
               SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 81110   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
               SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert PICKHEADER Failed (isp_CreatePickSlip)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
            END            
         END    
                
         IF @c_LinkPickSlipToPick = 'Y' AND @n_continue IN(1,2)
         BEGIN

           /*CS01 START*/
         DECLARE CUR_PickDetail CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
            SELECT DISTINCT PD.OrderKey, PD.Pickdetailkey 
         FROM PICKDETAIL PD WITH (NOLOCK) 
         WHERE PD.Orderkey = @c_Orderkey
         ORDER BY PD.Pickdetailkey
            
         OPEN CUR_PickDetail
  
         FETCH NEXT FROM CUR_PickDetail INTO @c_GetPickOrderkey, @c_PickDetailKey

       WHILE @@FETCH_STATUS <> -1  AND @n_continue IN (1,2)
         BEGIN  

            UPDATE PICKDETAIL WITH (ROWLOCK)  
            SET PickSlipNo = @c_PickSlipNo  
               ,TrafficCop = NULL  
            WHERE Orderkey = @c_GetPickOrderkey
            AND Pickslipno <> @c_Pickslipno
         AND Pickdetailkey = @c_PickDetailKey

            SELECT @n_err = @@ERROR  
            IF @n_err <> 0  
            BEGIN  
               SELECT @n_continue = 3  
               SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 81120   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
               SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update PICKDETAIL Failed (isp_CreatePickSlip)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
            END 

       FETCH NEXT FROM CUR_PickDetail INTO @c_GetPickOrderkey, @c_PickDetailKey          
         END   
         CLOSE CUR_PickDetail  
         DEALLOCATE CUR_PickDetail 
         
         /*CS01 END*/                            
         END
         
         IF @c_Refkeylookup = 'Y' AND @n_continue IN(1,2)
         BEGIN
            INSERT INTO RefKeyLookUp (PickDetailKey, PickSlipNo, OrderKey, OrderLineNumber)
               SELECT PD.PickdetailKey, @c_Pickslipno, PD.OrderKey, PD.OrderLineNumber 
               FROM PICKDETAIL PD (NOLOCK)  
               LEFT JOIN RefKeyLookup RKL (NOLOCK) ON PD.Pickdetailkey = RKL.Pickdetailkey             
               WHERE PD.Orderkey = @c_Orderkey
               AND RKL.Pickdetailkey IS NULL
            
            SELECT @n_err = @@ERROR  
            IF @n_err <> 0   
            BEGIN  
               SELECT @n_continue = 3  
               SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 81130   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
               SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert RefKeyLookUp Table Failed (isp_CreatePickSlip)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
            END                  
            
            UPDATE RefkeyLookup WITH (ROWLOCK)
            SET RefKeyLookup.Pickslipno = @c_Pickslipno
            FROM PICKDETAIL PD (NOLOCK)  
            JOIN RefKeyLookup ON PD.Pickdetailkey = RefKeyLookup.Pickdetailkey             
            WHERE PD.Orderkey = @c_Orderkey
            AND RefKeyLookup.Pickslipno <> @c_PickslipNo
            
            SELECT @n_err = @@ERROR  
            IF @n_err <> 0   
            BEGIN  
               SELECT @n_continue = 3  
               SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 81131   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
               SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update RefKeyLookUp Table Failed (isp_CreatePickSlip)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
            END                              
         END
         
         IF @c_AutoScanIn = 'Y' 
         BEGIN
            IF NOT EXISTS (SELECT 1 FROM PICKINGINFO (NOLOCK) WHERE Pickslipno = @c_Pickslipno)
            BEGIN
               INSERT INTO PICKINGINFO(Pickslipno, ScanInDate)
               VALUES (@c_Pickslipno, GetDate())

               SELECT @n_err = @@ERROR  
               IF @n_err <> 0   
               BEGIN  
                  SELECT @n_continue = 3  
                  SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 81132   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
                  SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert PickingInfo Table Failed (isp_CreatePickSlip)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
               END                              
            END
         END          
      END
      ELSE IF ISNULL(@c_Loadkey,'') <> '' AND @c_ConsolidateByLoad = 'Y'  --create conso load pickslip for the load plan
      BEGIN
          SELECT @c_Pickslipno = ''
          
          SELECT @c_Pickslipno = Pickheaderkey
          FROM PICKHEADER(NOLOCK) 
          WHERE ExternOrderkey = @c_Loadkey 
          AND ISNULL(Orderkey,'') = ''
          
          IF ISNULL(@c_Pickslipno,'') = ''
          BEGIN            
             EXECUTE nspg_GetKey 'PICKSLIP',   9,   @c_Pickslipno OUTPUT,   @b_Success OUTPUT,   @n_err OUTPUT,   @c_errmsg OUTPUT                      
             SELECT @c_Pickslipno = 'P' + @c_Pickslipno      

             INSERT INTO PICKHEADER (PickHeaderKey, ExternOrderKey, Orderkey, PickType, Zone, Loadkey, Storerkey)  
                      VALUES (@c_Pickslipno , @c_Loadkey, '', '0', @c_PickslipType, @c_Loadkey, @c_Storerkey)              
               
             SELECT @n_err = @@ERROR  
             IF @n_err <> 0  
             BEGIN  
                SELECT @n_continue = 3  
                SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 81140   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
                SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert PICKHEADER Failed (isp_CreatePickSlip)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
             END              
         END   

         IF @c_LinkPickSlipToPick = 'Y' AND @n_continue IN(1,2)
         BEGIN
            -- TLTING01  
            DECLARE CUR_UPDPickDetail CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
            SELECT PICKDETAIL.Pickdetailkey   
            FROM PICKDETAIL (NOLOCK)  
            JOIN LOADPLANDETAIL (NOLOCK) ON PICKDETAIL.Orderkey = LOADPLANDETAIL.Orderkey  
            WHERE LOADPLANDETAIL.Loadkey = @c_Loadkey  
            AND PICKDETAIL.Pickslipno <> @c_Pickslipno  
      
            OPEN CUR_UPDPickDetail  
    
            FETCH NEXT FROM CUR_UPDPickDetail INTO @c_LD_PickDetailKey  
  
            WHILE @@FETCH_STATUS <> -1  AND @n_continue IN (1,2)  
            BEGIN    
  
              UPDATE PICKDETAIL WITH (ROWLOCK)    
               SET PICKDETAIL.PickSlipNo = @c_PickSlipNo    
                  ,PICKDETAIL.TrafficCop = NULL    
               FROM PICKDETAIL  
               WHERE PICKDETAIL.Pickdetailkey = @c_LD_PickDetailKey  
               AND PICKDETAIL.Pickslipno <> @c_Pickslipno  
  
               SELECT @n_err = @@ERROR    
               IF @n_err <> 0    
               BEGIN    
                  SELECT @n_continue = 3    
                  SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 81150   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
                  SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update PICKDETAIL Failed (isp_CreatePickSlip)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '    
               END      
   
               FETCH NEXT FROM CUR_UPDPickDetail INTO @c_LD_PickDetailKey            
            END     
            CLOSE CUR_UPDPickDetail    
            DEALLOCATE CUR_UPDPickDetail   
            -- END TLTING01  
         END

         IF @c_Refkeylookup = 'Y' AND @n_continue IN(1,2)
         BEGIN
            INSERT INTO RefKeyLookUp (PickDetailKey, PickSlipNo, OrderKey, OrderLineNumber)
               SELECT PD.PickdetailKey, @c_Pickslipno, PD.OrderKey, PD.OrderLineNumber 
               FROM LOADPLANDETAIL LD (NOLOCK)
               JOIN PICKDETAIL PD (NOLOCK) ON LD.Orderkey = PD.Orderkey                
               LEFT JOIN RefKeyLookup RKL (NOLOCK) ON PD.Pickdetailkey = RKL.Pickdetailkey               
               WHERE LD.Loadkey = @c_Loadkey
               AND RKL.Pickdetailkey IS NULL
            
            SELECT @n_err = @@ERROR  
            IF @n_err <> 0              
            BEGIN  
               SELECT @n_continue = 3  
               SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 81160   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
               SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert RefKeyLookUp Table Failed (isp_CreatePickSlip)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
            END                  

            UPDATE RefkeyLookup WITH (ROWLOCK)
            SET RefKeyLookup.Pickslipno = @c_Pickslipno
            FROM LOADPLANDETAIL LD (NOLOCK)
            JOIN PICKDETAIL PD (NOLOCK) ON LD.Orderkey = PD.Orderkey                
            JOIN RefKeyLookup ON PD.Pickdetailkey = RefKeyLookup.Pickdetailkey               
            WHERE LD.Loadkey = @c_Loadkey
            AND RefKeyLookup.Pickslipno <> @c_PickslipNo
            
            SELECT @n_err = @@ERROR  
            IF @n_err <> 0   
            BEGIN  
               SELECT @n_continue = 3  
               SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 81161   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
               SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update RefKeyLookUp Table Failed (isp_CreatePickSlip)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
            END                                         
         END         
         
         IF @c_AutoScanIn = 'Y' 
         BEGIN
            IF NOT EXISTS (SELECT 1 FROM PICKINGINFO (NOLOCK) WHERE Pickslipno = @c_Pickslipno)
            BEGIN
               INSERT INTO PICKINGINFO(Pickslipno, ScanInDate)
               VALUES (@c_Pickslipno, GetDate())

               SELECT @n_err = @@ERROR  
               IF @n_err <> 0   
               BEGIN  
                  SELECT @n_continue = 3  
                  SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 81151   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
                  SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert PickingInfo Table Failed (isp_CreatePickSlip)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
               END                              
            END
         END                             
      END
      ELSE IF ISNULL(@c_Loadkey,'') <> '' AND @c_ConsolidateByLoad <> 'Y'  --create discrete orders pickslip for the load plan
      BEGIN
         DECLARE CUR_LOAD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
            SELECT DISTINCT LD.OrderKey, ISNULL(PH.Pickheaderkey,'') 
            FROM LOADPLANDETAIL LD (NOLOCK)  
            LEFT JOIN PICKHEADER PH (NOLOCK) ON LD.Orderkey = PH.Orderkey 
            WHERE LD.Loadkey = @c_Loadkey
            AND (PH.Orderkey IS NULL OR @c_LinkPickSlipToPick = 'Y' OR @c_Refkeylookup = 'Y') --no pickslip or need to re-update pickslipno to pickdetail/refkeylookup if not exist
            ORDER BY LD.Orderkey
  
         OPEN CUR_LOAD
  
         FETCH NEXT FROM CUR_LOAD INTO @c_Orderkey, @c_Pickslipno
   
         WHILE @@FETCH_STATUS <> -1  AND @n_continue IN (1,2)
         BEGIN                        
            IF ISNULL(@c_PickSlipno,'') = ''
            BEGIN      
               EXECUTE nspg_GetKey 'PICKSLIP',   9,   @c_Pickslipno OUTPUT,   @b_Success OUTPUT,   @n_err OUTPUT,   @c_errmsg OUTPUT                      
               SELECT @c_Pickslipno = 'P' + @c_Pickslipno      
               
               INSERT INTO PICKHEADER (PickHeaderKey, ExternOrderKey, Orderkey, PickType, Zone, Storerkey)  
                        VALUES (@c_Pickslipno , '', @c_Orderkey, '0', @c_PickslipType, @c_Storerkey)              
                 
               SELECT @n_err = @@ERROR  
               IF @n_err <> 0  
               BEGIN  
                  SELECT @n_continue = 3  
                  SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 81170   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
                  SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert PICKHEADER Failed (isp_CreatePickSlip)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
               END      
            END      

            IF @c_LinkPickSlipToPick = 'Y' AND @n_continue IN(1,2)
            BEGIN

         /*CS01 START*/
         DECLARE CUR_PickDetail CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
            SELECT DISTINCT PD.OrderKey, PD.Pickdetailkey 
         FROM PICKDETAIL PD WITH (NOLOCK) 
         WHERE PD.Orderkey = @c_Orderkey
         ORDER BY PD.Pickdetailkey
            
         OPEN CUR_PickDetail
  
         FETCH NEXT FROM CUR_PickDetail INTO @c_GetPickOrderkey, @c_PickDetailKey

       WHILE @@FETCH_STATUS <> -1  AND @n_continue IN (1,2)
         BEGIN  

               UPDATE PICKDETAIL WITH (ROWLOCK)  
               SET PickSlipNo = @c_PickSlipNo  
                  ,TrafficCop = NULL  
               WHERE Orderkey = @c_GetPickOrderkey
               AND Pickslipno <> @c_Pickslipno
            AND Pickdetailkey = @c_PickDetailKey
               
               SELECT @n_err = @@ERROR  
               IF @n_err <> 0  
               BEGIN  
                  SELECT @n_continue = 3  
                  SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 81180   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
                  SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update PICKDETAIL Failed (isp_CreatePickSlip)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
               END
            
        FETCH NEXT FROM CUR_PickDetail INTO @c_GetPickOrderkey, @c_PickDetailKey          
         END   
         CLOSE CUR_PickDetail  
         DEALLOCATE CUR_PickDetail 
         
         /*CS01 END*/          
                                        
            END

            IF @c_Refkeylookup = 'Y' AND @n_continue IN(1,2)
            BEGIN
               INSERT INTO RefKeyLookUp (PickDetailKey, PickSlipNo, OrderKey, OrderLineNumber)
                  SELECT PD.PickdetailKey, @c_Pickslipno, PD.OrderKey, PD.OrderLineNumber 
                  FROM PICKDETAIL PD (NOLOCK)  
                  LEFT JOIN RefKeyLookup RKL (NOLOCK) ON PD.Pickdetailkey = RKL.Pickdetailkey               
                  WHERE PD.Orderkey = @c_Orderkey
                  AND RKL.Pickdetailkey IS NULL
               
               SELECT @n_err = @@ERROR  
               IF @n_err <> 0   
               BEGIN  
                  SELECT @n_continue = 3  
                  SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 81190   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
                  SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert RefKeyLookUp Table Failed (isp_CreatePickSlip)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
               END                  

               UPDATE RefkeyLookup WITH (ROWLOCK)
               SET RefKeyLookup.Pickslipno = @c_Pickslipno
               FROM PICKDETAIL PD (NOLOCK)  
               JOIN RefKeyLookup ON PD.Pickdetailkey = RefKeyLookup.Pickdetailkey             
               WHERE PD.Orderkey = @c_Orderkey
               AND RefKeyLookup.Pickslipno <> @c_PickslipNo
               
               SELECT @n_err = @@ERROR  
               IF @n_err <> 0   
               BEGIN  
                  SELECT @n_continue = 3  
                  SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 81191   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
                  SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update RefKeyLookUp Table Failed (isp_CreatePickSlip)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
               END                              
            END

            IF @c_AutoScanIn = 'Y' 
            BEGIN
               IF NOT EXISTS (SELECT 1 FROM PICKINGINFO (NOLOCK) WHERE Pickslipno = @c_Pickslipno)
               BEGIN
                  INSERT INTO PICKINGINFO(Pickslipno, ScanInDate)
                  VALUES (@c_Pickslipno, GetDate())
            
                  SELECT @n_err = @@ERROR  
                  IF @n_err <> 0   
                  BEGIN  
                     SELECT @n_continue = 3  
                     SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 81192   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
                     SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert PickingInfo Table Failed (isp_CreatePickSlip)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
                  END                              
               END
            END                                        
            
            FETCH NEXT FROM CUR_LOAD INTO @c_Orderkey, @c_Pickslipno            
         END   
         CLOSE CUR_LOAD  
         DEALLOCATE CUR_LOAD 
      END              
      ELSE IF ISNULL(@c_Wavekey,'') <> '' AND @c_ConsolidateByLoad = 'Y'  --create conso load pickslip for the wave
      BEGIN
         DECLARE CUR_WAVE CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
            SELECT DISTINCT O.Loadkey, ISNULL(PH.Pickheaderkey,'')
            FROM WAVEDETAIL WD (NOLOCK)  
            JOIN ORDERS O (NOLOCK) ON WD.Orderkey = O.Orderkey
            LEFT JOIN PICKHEADER PH (NOLOCK) ON O.Loadkey = PH.ExternOrderkey AND ISNULL(PH.Orderkey,'') = '' 
            WHERE WD.Wavekey = @c_Wavekey
            AND (PH.ExternOrderkey IS NULL OR @c_LinkPickSlipToPick = 'Y' OR @c_Refkeylookup = 'Y') --no pickslip or need to re-update pickslipno to pickdetail/refkeylookup if not exist
            ORDER BY O.Loadkey
  
         OPEN CUR_WAVE
         
         FETCH NEXT FROM CUR_WAVE INTO @c_Loadkey, @c_Pickslipno

         WHILE @@FETCH_STATUS <> -1  AND @n_continue IN (1,2)
         BEGIN                        
            IF ISNULL(@c_Pickslipno,'') = ''
            BEGIN
               EXECUTE nspg_GetKey 'PICKSLIP',   9,   @c_Pickslipno OUTPUT,   @b_Success OUTPUT,   @n_err OUTPUT,   @c_errmsg OUTPUT                      
               SELECT @c_Pickslipno = 'P' + @c_Pickslipno      
               
               INSERT INTO PICKHEADER (PickHeaderKey, ExternOrderKey, Orderkey, PickType, Zone, Loadkey, Storerkey)  
                        VALUES (@c_Pickslipno , @c_Loadkey, '', '0', @c_PickslipType, @c_Loadkey, @c_Storerkey)              
                 
               SELECT @n_err = @@ERROR  
               IF @n_err <> 0  
               BEGIN  
                  SELECT @n_continue = 3  
                  SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 81200   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
                  SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert PICKHEADER Failed (isp_CreatePickSlip)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
               END
            END

            IF @c_LinkPickSlipToPick = 'Y' AND @n_continue IN(1,2)
            BEGIN
               --(Wan01) - START
               SET @CUR_UPD_PD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
                  SELECT PICKDETAIL.PickDetailKey
                  FROM dbo.PICKDETAIL WITH (NOLOCK)
                  JOIN LOADPLANDETAIL (NOLOCK) ON PICKDETAIL.Orderkey = LOADPLANDETAIL.Orderkey
                  WHERE LOADPLANDETAIL.Loadkey = @c_Loadkey
                  AND PICKDETAIL.PickSlipNo <> @c_Pickslipno
               
               OPEN @CUR_UPD_PD
   
               FETCH NEXT FROM @CUR_UPD_PD INTO @c_LD_PickDetailKey 
               WHILE @@FETCH_STATUS <> -1 AND @n_Continue IN (1,2) 
               BEGIN   
                  UPDATE PICKDETAIL WITH (ROWLOCK)  
                  SET PICKDETAIL.PickSlipNo = @c_PickSlipNo  
                     ,PICKDETAIL.TrafficCop = NULL  
                  WHERE PICKDETAIL.PickDetailKey = @c_LD_PickDetailKey                  
                  AND PICKDETAIL.PickSlipNo <> @c_Pickslipno
   
                  SELECT @n_err = @@ERROR  
                  IF @n_err <> 0  
                  BEGIN  
                     SELECT @n_continue = 3  
                     SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 81210   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
                     SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update PICKDETAIL Failed (isp_CreatePickSlip)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
                  END
                  FETCH NEXT FROM @CUR_UPD_PD INTO @c_LD_PickDetailKey 
               END
               CLOSE @CUR_UPD_PD
               DEALLOCATE @CUR_UPD_PD                                                
            END

            IF @c_Refkeylookup = 'Y' AND @n_continue IN(1,2)
            BEGIN
               INSERT INTO RefKeyLookUp (PickDetailKey, PickSlipNo, OrderKey, OrderLineNumber)
                  SELECT PD.PickdetailKey, @c_Pickslipno, PD.OrderKey, PD.OrderLineNumber 
                  FROM LOADPLANDETAIL LD (NOLOCK)
                  JOIN PICKDETAIL PD (NOLOCK) ON LD.Orderkey = PD.Orderkey 
                  LEFT JOIN RefKeyLookup RKL (NOLOCK) ON PD.Pickdetailkey = RKL.Pickdetailkey             
                  WHERE LD.Loadkey = @c_Loadkey
                  AND RKL.Pickdetailkey IS NULL
               
               SELECT @n_err = @@ERROR  
               IF @n_err <> 0   
               BEGIN  
                  SELECT @n_continue = 3  
                  SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 81230   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
                  SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert RefKeyLookUp Table Failed (isp_CreatePickSlip)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
               END                  

               UPDATE RefkeyLookup WITH (ROWLOCK)
               SET RefKeyLookup.Pickslipno = @c_Pickslipno
               FROM LOADPLANDETAIL LD (NOLOCK)
               JOIN PICKDETAIL PD (NOLOCK) ON LD.Orderkey = PD.Orderkey                
               JOIN RefKeyLookup ON PD.Pickdetailkey = RefKeyLookup.Pickdetailkey               
               WHERE LD.Loadkey = @c_Loadkey
               AND RefKeyLookup.Pickslipno <> @c_PickslipNo
               
               SELECT @n_err = @@ERROR  
               IF @n_err <> 0   
               BEGIN  
                  SELECT @n_continue = 3  
                  SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 81231   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
                  SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update RefKeyLookUp Table Failed (isp_CreatePickSlip)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
               END                                         
            END

            IF @c_AutoScanIn = 'Y' 
            BEGIN
               IF NOT EXISTS (SELECT 1 FROM PICKINGINFO (NOLOCK) WHERE Pickslipno = @c_Pickslipno)
               BEGIN
                  INSERT INTO PICKINGINFO(Pickslipno, ScanInDate)
                  VALUES (@c_Pickslipno, GetDate())
            
                  SELECT @n_err = @@ERROR  
                  IF @n_err <> 0   
                  BEGIN  
                     SELECT @n_continue = 3  
                     SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 81232   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
                     SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert PickingInfo Table Failed (isp_CreatePickSlip)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
                  END                              
               END
            END                             
            
            FETCH NEXT FROM CUR_WAVE INTO @c_Loadkey, @c_Pickslipno            
         END   
         CLOSE CUR_WAVE  
         DEALLOCATE CUR_WAVE 
      END                    
      ELSE IF ISNULL(@c_Wavekey,'') <> '' AND @c_ConsolidateByLoad <> 'Y'  --create discrete orders pickslip for the wave
      BEGIN
         DECLARE CUR_WAVE CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
            SELECT DISTINCT WD.OrderKey, ISNULL(PH.Pickheaderkey,'') 
            FROM WAVEDETAIL WD (NOLOCK)  
            LEFT JOIN PICKHEADER PH (NOLOCK) ON WD.Orderkey = PH.Orderkey 
            WHERE WD.Wavekey = @c_Wavekey
            AND (PH.Orderkey IS NULL OR @c_LinkPickSlipToPick = 'Y' OR @c_Refkeylookup = 'Y') --no pickslip or need to re-update pickslipno to pickdetail/refkeylookup if not exist
            ORDER BY WD.Orderkey
  
         OPEN CUR_WAVE
  
         FETCH NEXT FROM CUR_WAVE INTO @c_Orderkey, @c_Pickslipno
   
         WHILE @@FETCH_STATUS <> -1  AND @n_continue IN (1,2)
         BEGIN            
            IF ISNULL(@c_Pickslipno,'') = ''
            BEGIN
               EXECUTE nspg_GetKey 'PICKSLIP',   9,   @c_Pickslipno OUTPUT,   @b_Success OUTPUT,   @n_err OUTPUT,   @c_errmsg OUTPUT                      
               SELECT @c_Pickslipno = 'P' + @c_Pickslipno      
               
               INSERT INTO PICKHEADER (PickHeaderKey, ExternOrderKey, Orderkey, PickType, Zone, Storerkey)  
                        VALUES (@c_Pickslipno , '', @c_Orderkey, '0', @c_PickslipType, @c_Storerkey)              
                 
               SELECT @n_err = @@ERROR  
               IF @n_err <> 0  
               BEGIN  
                  SELECT @n_continue = 3  
                  SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 81240   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
                  SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert PICKHEADER Failed (isp_CreatePickSlip)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
               END            
            END

            IF @c_LinkPickSlipToPick = 'Y' AND @n_continue IN(1,2)
            BEGIN

         /*CS01 START*/
         DECLARE CUR_PickDetail CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
            SELECT DISTINCT PD.OrderKey, PD.Pickdetailkey 
         FROM PICKDETAIL PD WITH (NOLOCK) 
         WHERE PD.Orderkey = @c_Orderkey
         ORDER BY PD.Pickdetailkey
            
         OPEN CUR_PickDetail
  
         FETCH NEXT FROM CUR_PickDetail INTO @c_GetPickOrderkey, @c_PickDetailKey

       WHILE @@FETCH_STATUS <> -1  AND @n_continue IN (1,2)
         BEGIN
        
               UPDATE PICKDETAIL WITH (ROWLOCK)  
               SET PickSlipNo = @c_PickSlipNo  
                  ,TrafficCop = NULL  
               WHERE Orderkey = @c_GetPickOrderkey
               AND Pickslipno <> @c_Pickslipno
            AND Pickdetailkey = @c_PickDetailKey

               SELECT @n_err = @@ERROR  
               IF @n_err <> 0  
               BEGIN  
                  SELECT @n_continue = 3  
                  SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 81250   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
                  SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update PICKDETAIL Failed (isp_CreatePickSlip)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
               END 
            
        FETCH NEXT FROM CUR_PickDetail INTO @c_GetPickOrderkey, @c_PickDetailKey          
         END   
         CLOSE CUR_PickDetail  
         DEALLOCATE CUR_PickDetail 
         
         /*CS01 END*/          
                                        
            END
            
            IF @c_Refkeylookup = 'Y' AND @n_continue IN(1,2)
            BEGIN
               INSERT INTO RefKeyLookUp (PickDetailKey, PickSlipNo, OrderKey, OrderLineNumber)
                  SELECT PD.PickdetailKey, @c_Pickslipno, PD.OrderKey, PD.OrderLineNumber 
                  FROM PICKDETAIL PD (NOLOCK)  
                  LEFT JOIN RefKeyLookup RKL (NOLOCK) ON PD.Pickdetailkey = RKL.Pickdetailkey             
                  WHERE PD.Orderkey = @c_Orderkey
                  AND RKL.Pickdetailkey IS NULL
               
               SELECT @n_err = @@ERROR  
               IF @n_err <> 0   
               BEGIN  
                  SELECT @n_continue = 3  
                  SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 81260   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
                  SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert RefKeyLookUp Table Failed (isp_CreatePickSlip)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
               END                  

               UPDATE RefkeyLookup WITH (ROWLOCK)
               SET RefKeyLookup.Pickslipno = @c_Pickslipno
               FROM PICKDETAIL PD (NOLOCK)  
               JOIN RefKeyLookup ON PD.Pickdetailkey = RefKeyLookup.Pickdetailkey             
               WHERE PD.Orderkey = @c_Orderkey
               AND RefKeyLookup.Pickslipno <> @c_PickslipNo
               
               SELECT @n_err = @@ERROR  
               IF @n_err <> 0   
               BEGIN  
                  SELECT @n_continue = 3  
                  SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 81261   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
                  SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update RefKeyLookUp Table Failed (isp_CreatePickSlip)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
               END                              
            END

            IF @c_AutoScanIn = 'Y' 
            BEGIN
               IF NOT EXISTS (SELECT 1 FROM PICKINGINFO (NOLOCK) WHERE Pickslipno = @c_Pickslipno)
               BEGIN
                  INSERT INTO PICKINGINFO(Pickslipno, ScanInDate)
                  VALUES (@c_Pickslipno, GetDate())
            
                  SELECT @n_err = @@ERROR  
                  IF @n_err <> 0   
                  BEGIN  
                     SELECT @n_continue = 3  
                     SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 81261   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
                     SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert PickingInfo Table Failed (isp_CreatePickSlip)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
                  END                              
               END
            END                             
            
            FETCH NEXT FROM CUR_WAVE INTO @c_Orderkey, @c_Pickslipno            
         END   
         CLOSE CUR_WAVE  
         DEALLOCATE CUR_WAVE 
      END              
   END
   
   QUIT_SP:
   
    IF @n_Continue=3  -- Error Occured - Process AND Return
    BEGIN
       SELECT @b_Success = 0
       IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCnt
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
       EXECUTE dbo.nsp_LogError @n_Err, @c_Errmsg, 'isp_CreatePickSlip'    
       RAISERROR (@c_Errmsg, 16, 1) WITH SETERROR    -- SQL2012
       RETURN
    END
    ELSE
    BEGIN
       SELECT @b_Success = 1
       WHILE @@TRANCOUNT > @n_StartTCnt
       BEGIN
         COMMIT TRAN
       END
       RETURN
    END  
END  

GO