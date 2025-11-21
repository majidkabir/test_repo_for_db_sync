SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/      
/* Stored Procedure: lsp_Unallocation_Wrapper                           */      
/* Creation Date: 14-Mar-2018                                           */      
/* Copyright: LFLogistics                                               */      
/* Written by:                                                          */      
/*                                                                      */      
/* Purpose: Unallocation                                                */      
/*                                                                      */      
/* Called By: Unallocation                                              */      
/*                                                                      */      
/* PVCS Version: 1.6                                                    */      
/*                                                                      */      
/* Version: 8.0                                                         */      
/*                                                                      */      
/* Data Modifications:                                                  */      
/*                                                                      */      
/* Updates:                                                             */      
/* Date        Author   Ver   Purposes                                  */      
/* 28-Dec-2020 SWT01    1.0   Adding Begin Try/Catch                    */    
/* 05-Jan-2021 Wan01    1.2   Execute login if current user<>@c_username*/    
/*                            Return Error Msg for Big Outer Catch      */    
/*                            Do Not Raise error for WM Script          */    
/* 04-Oct-2021 CheeMun  1.3   JSM-23942 - Extend @c_Sku Length          */    
/* 21-DEC-2021 Wan02    1.4   LFWM-3146 - UAT - TW  Pick Management -   */    
/*                            Order Unallocation - cannot unallocate    */    
/*                            order at once                             */    
/* 21-DEC-2021 Wan02    1.4   DevOps Combine Script                     */    
/* 28-Jan-2022 Wan03    1.5   LFWM-3259 - UAT RG  Unpack function and   */    
/*                            pack management changes (#LFWM3259)       */    
/* 22-APR-2022 Wan04    1.6   LFWM-3499 - [CN] UAT Carters - Outbound   */    
/*                            unallocate issue                          */    
/* 26-AUG-2022 KY01     1.7   INC1891678-AddOn close cursorCUR_PICKDETAIL*/  
/* 13-OCT-2022 KY02     1.8   INC1929382-AddOn @c_PickHeader_Loadkey check*/
/* 22-APR-2023 Wan05    1.9   JSM-84413(AikLiang). Not to delete Pack if */
/*                            not all pickdetail for conso loadkey are  */
/*                            deleted (UWP-29893)                       */  
/* 10-JAN-2025 SSA01    2.0   UWP-23317-Added validationn to redirect   */
/*                            to pickserialnumber tab                   */
/* 29-Nov-2024 TLTING01 2.1   UWP-28805 Blocking tune                   */
/* 11-Feb-2025 SSA02    2.2   UWP-29893 Removed @c_Pickdetailkey's empty*/
/*                            check to restrict unallocation for packing*/
/*                            orders while click on option1             */
/* 11-Feb-2025 SSA03    2.3   UWP-29893 Reverting changes to fix PROD   */
/*                            issue*/
/************************************************************************/       
CREATE   PROCEDURE [WM].[lsp_Unallocation_Wrapper]
    @c_Storerkey NVARCHAR(15) = ''      --optional    
   ,@c_Pickdetailkey NVARCHAR(10) = ''  --optional      
   ,@c_Orderkey NVARCHAR(10) = ''       --optional    
   ,@c_OrderLineNumber NVARCHAR(5) = '' --optional    
   ,@c_Loadkey NVARCHAR(10) = ''        --optional    
   ,@c_Wavekey NVARCHAR(10) = ''        --optional    
   ,@c_Sku     NVARCHAR(20) = ''        --optional      --JSM-23942    
   ,@b_Success INT = 1 OUTPUT     
   ,@n_Err INT = 0 OUTPUT    
   ,@c_ErrMsg NVARCHAR(250) = '' OUTPUT    
   ,@c_UserName NVARCHAR(128) = ''    
   ,@c_UnAllocateFrom NVARCHAR(20) = ''  --ORDER = Shipment Order Screen (Pickdetaileky)    
                                         --UAORDER = Unallocate Orders screen   (orderkey)    
                                         --UAPICKLINE = Unallocate Pickdetail Lines screen  (pickdetailkey)    
                                         --UALOAD = Unallocate LoadPlan screen (storerkey,loadkey,sku)    
                                         --UATMLOAD = Unallocate TM Load Screen (storerkey, loadkey)    
                                         --UAWAVE = Unallocate Wave screen (storerkey, wavekey)    
                                         --UAWAVEBYLOAD = Unallocate Wavebyload screen (storerkey, wavekey, loadkey)    
                                         --UAWAVEBYSKU = Unallocate Wavebysku screen (storerkey, wavekey, sku)    
AS    
BEGIN     
   SET NOCOUNT ON    
   SET QUOTED_IDENTIFIER OFF    
   SET ANSI_NULLS OFF    
   SET CONCAT_NULL_YIELDS_NULL OFF    
       
   DECLARE @c_SQL             NVARCHAR(1000) = ''    
         , @c_SQLParms        NVARCHAR(1000) = ''    
             
   --(Wan03) - START    
   DECLARE @c_PickHeader_Orderkey   NVARCHAR(10) = ''    
         , @c_PickHeader_Loadkey    NVARCHAR(10) = ''    
         , @c_PickHeaderKey         NVARCHAR(10) = ''    
         , @c_PackStatus            NVARCHAR(10) = '' 
         , @c_PackType              CHAR(1)      = 'D'             
             
   DECLARE @CUR_DELPICKSLIP   CURSOR    
        
   DECLARE @t_UnAllocate  TABLE ( Orderkey      NVARCHAR(10) NOT NULL DEFAULT('') PRIMARY KEY    
                                 ,Loadkey       NVARCHAR(10) NOT NULL DEFAULT('')     
                                 ,PickHeaderKey NVARCHAR(10) NOT NULL DEFAULT('')   
                                 ,PackType      CHAR(1)      NOT NULL DEFAULT('')         --(Wan05)                                  
                                 )     
   --(Wan03) - END        
   SET @n_Err = 0     
        
   IF SUSER_SNAME() <> @c_UserName    --(Wan01)    
   BEGIN    
      EXEC [WM].[lsp_SetUser] @c_UserName = @c_UserName OUTPUT, @n_Err = @n_Err OUTPUT, @c_ErrMsg = @c_ErrMsg OUTPUT    
        
      IF @n_Err <> 0     
      BEGIN    
         GOTO EXIT_SP    
      END    
        
      EXECUTE AS LOGIN = @c_UserName    
   END    
        
   BEGIN TRY -- SWT01 - Begin Outer Begin Try       
        
      DECLARE @n_Continue              INT    
            ,@n_starttcnt              INT    
    
      SELECT @n_starttcnt=@@TRANCOUNT, @n_err=0, @b_success=1, @c_errmsg='', @n_continue=1    
    
      BEGIN TRAN             --(Wan02)    
      IF @n_continue IN(1,2)    
      BEGIN          
         IF ISNULL(@c_Pickdetailkey,'') = '' AND ISNULL(@c_Orderkey,'') = '' AND ISNULL(@c_Loadkey,'') = '' AND ISNULL(@c_Wavekey,'') = ''    
         BEGIN    
            SELECT @n_continue = 3      
            SELECT @n_Err = 551801    
            SELECT @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_Err) +     
                  ': All key parameters are empty. (lsp_Unallocation_Wrapper)'    
         END           
      END    
          
      IF @c_UnAllocateFrom NOT IN ( 'UALOAD', 'UAWAVE', 'UAWAVEBYLOAD', 'UAWAVEBYSKU' )             --(Wan04) - Thease UnAllocateFrom will delete pack data    
      BEGIN    
         IF ISNULL(@c_Pickdetailkey,'') <> ''    
         BEGIN    
             INSERT INTO @t_UnAllocate    
                 (    
                     Orderkey,    
                     Loadkey    
                 )    
             SELECT o.OrderKey, o.LoadKey    
             FROM dbo.PICKDETAIL AS p WITH (NOLOCK)    
             JOIN dbo.ORDERS AS o WITH (NOLOCK) ON o.OrderKey = p.OrderKey    
             WHERE p.PickDetailKey = @c_Pickdetailkey    
             GROUP BY o.OrderKey, o.LoadKey    
             ORDER BY o.LoadKey, o.OrderKey    
         END    
       
         IF ISNULL(@c_Orderkey,'') <> ''    
         BEGIN    
             INSERT INTO @t_UnAllocate    
                 (    
                     Orderkey,    
                     Loadkey    
                 )    
             SELECT o.OrderKey, o.LoadKey    
             FROM dbo.ORDERS AS o WITH (NOLOCK)     
             WHERE o.OrderKey = @c_Orderkey    
             AND NOT EXISTS (SELECT 1 FROM @t_UnAllocate AS tp WHERE tp.Orderkey = o.Orderkey)    
             GROUP BY o.OrderKey, o.LoadKey    
             ORDER BY o.LoadKey, o.OrderKey    
         END    
       
         IF ISNULL(@c_Loadkey,'') <> ''    
         BEGIN    
             INSERT INTO @t_UnAllocate    
                 (    
                     Orderkey,    
                     Loadkey    
                 )    
             SELECT lpd.OrderKey, lpd.LoadKey    
             FROM dbo.LoadPlanDetail AS lpd WITH (NOLOCK)     
             WHERE lpd.Loadkey = @c_Loadkey    
             AND NOT EXISTS (SELECT 1 FROM @t_UnAllocate AS tp WHERE tp.Orderkey = lpd.Orderkey)    
             GROUP BY lpd.OrderKey, lpd.LoadKey    
             ORDER BY lpd.LoadKey, lpd.OrderKey    
         END    
       
         IF ISNULL(@c_Wavekey,'') <> ''    
         BEGIN    
             INSERT INTO @t_UnAllocate    
                 (    
                     Orderkey,    
                     Loadkey    
                 )    
             SELECT lpd.OrderKey, lpd.LoadKey    
             FROM dbo.WAVEDETAIL AS w WITH (NOLOCK)     
             JOIN dbo.LoadPlanDetail AS lpd WITH (NOLOCK) ON lpd.OrderKey = w.OrderKey    
             WHERE w.Wavekey = @c_Wavekey    
             AND NOT EXISTS (SELECT 1 FROM @t_UnAllocate AS tp WHERE tp.Orderkey = w.Orderkey)    
             GROUP BY lpd.OrderKey, lpd.LoadKey    
             ORDER BY lpd.LoadKey, lpd.OrderKey    
         END    
          
         SET @CUR_DELPICKSLIP = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
         SELECT tph.Orderkey    
            ,   tph.Loadkey    
         FROM @t_UnAllocate AS tph    
         ORDER BY tph.Orderkey    
          
         OPEN @CUR_DELPICKSLIP    
          
         FETCH NEXT FROM @CUR_DELPICKSLIP INTO @c_PickHeader_Orderkey    
                                             , @c_PickHeader_Loadkey    
          
         WHILE @@FETCH_STATUS <> -1    
         BEGIN                                  
            SET @c_PickHeaderKey = ''
            SET @c_PackType = 'D'                                             --(Wan05)                
             
            SELECT TOP 1 @c_PickHeaderKey = p.PickHeaderKey                   --(Wan05) 
            FROM dbo.PICKHEADER AS p WITH (NOLOCK)    
            WHERE p.OrderKey = @c_PickHeader_Orderkey  
            ORDER BY p.PickHeaderKey DESC                                     --(Wan05)  
             
            --IF @c_PickHeaderKey = ''    
         IF ISNULL(@c_PickHeader_Loadkey,'') <> '' AND @c_PickHeaderKey = ''   --KY02
            BEGIN  
               SET @c_PackType = 'C'                                          --(Wan05)                  
               SELECT TOP 1 @c_PickHeaderKey = p.PickHeaderKey    
               FROM dbo.PICKHEADER AS p WITH (NOLOCK)    
               WHERE p.ExternOrderKey = @c_PickHeader_Loadkey    
               AND p.OrderKey = ''
               ORDER BY p.PickHeaderKey DESC                                  --(Wan05)     
            END    
             
            --IF @c_PickHeaderKey = ''    
            IF ISNULL(@c_PickHeader_Loadkey,'') <> '' AND @c_PickHeaderKey = ''    --KY02
            BEGIN  
               SET @c_PackType = 'C'                                          --(Wan05)                    
               SELECT TOP 1 @c_PickHeaderKey = p.PickHeaderKey    
               FROM dbo.PICKHEADER AS p WITH (NOLOCK)    
               WHERE p.Loadkey = @c_PickHeader_Loadkey    
               AND p.OrderKey = ''  
               ORDER BY p.PickHeaderKey DESC                                  --(Wan05)                  
            END    
             
            IF @c_PickHeaderKey <> ''    
            BEGIN    
               SET @c_PackStatus = ''    
               SELECT TOP 1 @c_PackStatus = ph.[Status]    
               FROM dbo.PackHeader AS ph WITH (NOLOCK)     
               JOIN dbo.PackDetail AS pd WITH (NOLOCK) ON pd.PickSlipNo = ph.PickSlipNo    
               WHERE ph.PickSlipNo = @c_PickHeaderKey    
                            
               IF ISNULL(@c_Pickdetailkey,'') = '' AND @c_PackStatus IN ( '0','9' ) --(SSA02)(SSA03)
               BEGIN     
                  SET @n_continue = 3      
                  SET @n_err = 551808    
                  SET @c_errmsg='NSQL'+CONVERT(char(6),@n_err)+': Pack data found. Unallocation Abort. (lsp_Unallocation_Wrapper)'     
                  GOTO EXIT_SP    
               END                      
    
               UPDATE @t_UnAllocate    
                  SET PickHeaderKey = @c_PickHeaderKey 
                    , PackType = @c_PackType                                  --(Wan05)                        
               WHERE Orderkey = @c_PickHeader_Orderkey    
                
            END             
            FETCH NEXT FROM @CUR_DELPICKSLIP INTO @c_PickHeader_Orderkey    
                                                , @c_PickHeader_Loadkey           
         END    
         CLOSE @CUR_DELPICKSLIP    
         DEALLOCATE @CUR_DELPICKSLIP    
         --(Wan03) - END    
      END--(Wan04) - END    
          
      IF @n_continue IN(1,2) AND @c_UnallocateFrom = 'UALOAD'        
      BEGIN    
         EXECUTE dbo.ispUnallocate_DynamicLPAlloc @c_Storerkey=@c_Storerkey, @c_Loadkey=@c_LoadKey, @c_Sku=@c_SKU     
    
         SET @n_err =  @@ERROR     
           
         IF @n_err <> 0    
         BEGIN    
            SELECT @n_continue = 3      
            SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 551802    
            SELECT @c_errmsg='NSQL'+CONVERT(char(6),@n_err)+': Execute dbo.ispUnallocate_DynamicLPAlloc Failed. (lsp_Unallocation_Wrapper)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '     
         END               
      END    
    
      IF @n_continue IN(1,2) AND @c_UnallocateFrom = 'UATMLOAD'        
      BEGIN    
         EXECUTE dbo.ispUnallocate_TMLoadPlan_Wrapper @c_Storerkey=@c_Storerkey, @c_Loadkey=@c_LoadKey    
    
         SET @n_err =  @@ERROR     
           
         IF @n_err <> 0    
         BEGIN    
            SELECT @n_continue = 3      
               SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 551803    
               SELECT @c_errmsg='NSQL'+CONVERT(char(6),@n_err)+': Execute dbo.ispUnallocate_TMLoadPlan_Wrapper Failed. (lsp_Unallocation_Wrapper)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '     
         END                    
      END    
    
      IF @n_continue IN(1,2) AND @c_UnallocateFrom = 'UAWAVE'        
      BEGIN    
         EXECUTE dbo.ispUnallocate_DynamicWaveAlloc_byWave @c_Storerkey=@c_Storerkey, @c_Wavekey=@c_waveKey     
    
         SET @n_err =  @@ERROR     
           
         IF @n_err <> 0    
         BEGIN    
            SELECT @n_continue = 3      
               SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 551804    
               SELECT @c_errmsg='NSQL'+CONVERT(char(6),@n_err)+': Execute dbo.ispUnallocate_DynamicWaveAlloc_byWave Failed. (lsp_Unallocation_Wrapper)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '     
         END                    
      END    
    
      IF @n_continue IN(1,2) AND @c_UnallocateFrom = 'UAWAVEBYLOAD'        
      BEGIN    
         EXECUTE dbo.ispUnallocate_DynamicWaveAlloc_byLoad @c_Storerkey=@c_Storerkey, @c_Wavekey=@c_WaveKey, @c_Loadkey=@c_Loadkey     
    
         SET @n_err =  @@ERROR     
           
         IF @n_err <> 0    
         BEGIN    
            SELECT @n_continue = 3      
               SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 551805    
               SELECT @c_errmsg='NSQL'+CONVERT(char(6),@n_err)+': Execute dbo.ispUnallocate_DynamicWaveAlloc_byLoad Failed. (lsp_Unallocation_Wrapper)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '     
         END                    
      END    
        
      IF @n_continue IN(1,2) AND @c_UnallocateFrom = 'UAWAVEBYSKU'        
      BEGIN    
         EXECUTE dbo.ispUnallocate_DynamicWaveAlloc_bySku @c_Storerkey=@c_Storerkey, @c_Wavekey=@c_WaveKey, @c_Sku=@c_Sku    
    
         SET @n_err =  @@ERROR     
           
         IF @n_err <> 0    
         BEGIN    
            SELECT @n_continue = 3      
               SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 551806    
               SELECT @c_errmsg='NSQL'+CONVERT(char(6),@n_err)+': Execute dbo.ispUnallocate_DynamicWaveAlloc_bySku Failed. (lsp_Unallocation_Wrapper)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '     
         END                    
      END    
  
      IF CURSOR_STATUS('GLOBAL','CUR_PICKDETAIL') >= 0         --KY01   
      BEGIN  
         CLOSE CUR_PICKDETAIL  
         DEALLOCATE CUR_PICKDETAIL  
      END  
      --SSA01 start---
      IF @n_continue IN(1,2) AND ISNULL(@c_UnallocateFrom, '') = 'UAPICKLINE'
         BEGIN
         IF EXISTS(SELECT  1 FROM dbo.PickDetail pd (NOLOCK)
            JOIN dbo.PickSerialNo psn (NOLOCK) ON psn.Pickdetailkey = pd.PickdetailKey
            WHERE psn.Pickdetailkey = @c_Pickdetailkey
            AND psn.SerialNo > '')
            BEGIN
               SELECT @n_continue = 3
               SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 551812
               SELECT @c_errmsg='NSQL'+CONVERT(char(6),@n_err)+': Allocated by Serial number and unallocate from pickserial number tab(lsp_Unallocation_Wrapper)'
            END
      END
      -- SSA01 END--
         
      -- tlting01
      WHILE @@TRANCOUNT > 0      
      BEGIN      
       COMMIT TRAN      
      END  
         
      IF @n_continue IN(1,2) AND ISNULL(@c_UnallocateFrom,'') IN ('','ORDER','UAORDER','UAPICKLINE')    
      BEGIN
         --(Wan02) - START    
         SET @c_SQL = N'DECLARE CUR_PICKDETAIL CURSOR FAST_FORWARD READ_ONLY FOR'    
                    + ' SELECT PD.Pickdetailkey'    
                    + ' FROM PICKDETAIL PD WITH (NOLOCK)'               
                    + ' JOIN ORDERS  OH WITH (NOLOCK) ON OH.Orderkey = PD.Orderkey'     
                    + CASE WHEN ISNULL(@c_Loadkey,'') = '' THEN '' ELSE ' JOIN dbo.LOADPLANDETAIL lpd WITH(NOLOCK) ON lpd.Orderkey = OH.Orderkey' END    
                    + CASE WHEN ISNULL(@c_Wavekey,'') = '' THEN '' ELSE ' JOIN dbo.WAVEDETAIL wd WITH(NOLOCK) ON wd.Orderkey = OH.Orderkey' END     
                    + ' WHERE  PD.Status <> ''9'''    
                    + CASE WHEN ISNULL(@c_Pickdetailkey,'')   = '' THEN '' ELSE ' AND PD.Pickdetailkey = @c_PickDetailkey' END                         
                    + CASE WHEN ISNULL(@c_Orderkey,'')        = '' THEN '' ELSE ' AND OH.Orderkey = @c_Orderkey' END     
                    + CASE WHEN ISNULL(@c_OrderLineNumber,'') = '' THEN '' ELSE ' AND PD.OrderLineNumber = @c_OrderLineNumber' END     
                    + CASE WHEN ISNULL(@c_Loadkey,'')         = '' THEN '' ELSE ' AND lpd.Loadkey = @c_Loadkey' END     
                    + CASE WHEN ISNULL(@c_Wavekey,'')         = '' THEN '' ELSE ' AND wd.Wavekey = @c_Wavekey' END     
                    + CASE WHEN ISNULL(@c_Storerkey,'')       = '' THEN '' ELSE ' AND OH.Storerkey = @c_Storerkey' END    
                    + CASE WHEN ISNULL(@c_Sku,'')             = '' THEN '' ELSE ' AND PD.Sku = @c_Sku' END      
                    + ' ORDER BY PD.PickdetailKey'      
    
         SET @c_SQLParms = N'@c_Pickdetailkey   NVARCHAR(10)'     
                         + ',@c_Loadkey         NVARCHAR(10)'    
                         + ',@c_Wavekey    NVARCHAR(10)'    
                         + ',@c_Orderkey        NVARCHAR(10)'    
                         + ',@c_OrderLineNumber NVARCHAR(5)'                               
                         + ',@c_Storerkey       NVARCHAR(15)'               
                         + ',@c_Sku             NVARCHAR(20)'      
    
         EXEC sp_ExecuteSQL @c_SQL     
                           ,@c_SQLParms     
                           ,@c_Pickdetailkey       
                           ,@c_Loadkey             
                           ,@c_Wavekey      
                           ,@c_Orderkey            
                           ,@c_OrderLineNumber                             
                           ,@c_Storerkey                    
                           ,@c_Sku                 
         --(Wan02) - END    
    
         OPEN CUR_PICKDETAIL    
           
         FETCH FROM CUR_PICKDETAIL INTO @c_Pickdetailkey    
           
         WHILE @@FETCH_STATUS=0 AND @n_continue IN(1,2)    
         BEGIN    
            --tlting01
            BEGIN TRAN 
            DELETE PICKDETAIL  WITH (ROWLOCK)             --(Wan02)    
            WHERE Pickdetailkey = @c_Pickdetailkey    
     
            SET @n_err =  @@ERROR     
    
            IF @n_err <> 0    
            BEGIN    
               SELECT @n_continue = 3      
               SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 551807    
               SELECT @c_errmsg='NSQL'+CONVERT(char(6),@n_err)+': Delete Pickdetailkey fail. (lsp_Unallocation_Wrapper)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '     
            END  
            ELSE
            BEGIN
               COMMIT TRAN
            END               
           
            FETCH FROM CUR_PICKDETAIL INTO @c_Pickdetailkey    
         END              
         CLOSE CUR_PICKDETAIL    
         DEALLOCATE CUR_PICKDETAIL         
      END   
           
      -- tlting01  
      --(Wan03) - START             
      --IF @@TRANCOUNT = 0    
      --BEGIN     
      --   BEGIN TRAN    
      --END   
    
      SET @CUR_DELPICKSLIP = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
      SELECT tph.PickHeaderKey    
      FROM @t_UnAllocate AS tph    
      WHERE tph.PickHeaderKey <> ''    
      AND NOT EXISTS (SELECT 1 FROM dbo.PICKDETAIL AS p WITH (NOLOCK) WHERE p.OrderKey = tph.Orderkey)    
      AND tph.PackType = 'D'                                         --(Wan05) - STaRT
      UNION  
      SELECT tph.PickHeaderKey    
      FROM @t_UnAllocate AS tph    
      WHERE tph.PickHeaderKey <> ''    
      AND NOT EXISTS (SELECT 1 FROM dbo.PICKDETAIL AS p WITH (NOLOCK)
                      JOIN dbo.ORDERS AS o WITH (NOLOCK) ON p.OrderKey = o.OrderKey
                      WHERE o.Loadkey = tph.Loadkey) 
      AND tph.PackType = 'C'        
      GROUP BY tph.PickHeaderKey   
      ORDER BY tph.PickHeaderKey                                     --(Wan05) - END
          
      OPEN @CUR_DELPICKSLIP    
          
      FETCH NEXT FROM @CUR_DELPICKSLIP INTO @c_PickHeaderKey    
          
      WHILE @@FETCH_STATUS <> -1 AND @n_continue IN (1,2)    
      BEGIN    
         IF EXISTS (SELECT 1 FROM dbo.PackHeader AS ph WITH (NOLOCK) WHERE ph.PickSlipNo = @c_PickHeaderKey AND ph.[Status] < '9')    
         BEGIN    
            IF EXISTS (SELECT 1 FROM dbo.PackDetail AS pd WITH (NOLOCK) WHERE pd.PickSlipNo = @c_PickHeaderKey)    
            BEGIN  
               --TLTING01   
               BEGIN TRAN  
               ;WITH delpack AS ( SELECT pd.PickSlipNo, pd.CartonNo, pd.LabelNo, pd.LabelLine     
                                    FROM dbo.PackDetail AS pd WITH (NOLOCK)    
                                    WHERE pd.PickSlipNo = @c_PickHeaderKey      
                                  )    
               DELETE p FROM dbo.PackDetail AS p WITH (ROWLOCK)    
               JOIN delpack AS d ON p.PickSlipNo = d.PickSlipNo AND p.CartonNo = d.CartonNo     
                                 AND p.LabelNo = d.LabelNo AND p.LabelLine = d.LabelLine        
                
               SET @n_err =  @@ERROR     
    
               IF @n_err <> 0    
               BEGIN    
                  SET @n_continue = 3      
                  SET @c_errmsg = ERROR_MESSAGE()    
                  SET @n_err = 551809    
                  SET @c_errmsg='NSQL'+CONVERT(char(6),@n_err)+': Delete PackDetail fail. (lsp_Unallocation_Wrapper)' + ' ( SQLSvr MESSAGE=' + @c_errmsg + ' ) '     
               END 
               ELSE
               BEGIN
                  COMMIT TRAN
               END      
            END     
                
            IF @n_continue IN (1,2)     
            BEGIN 
               --TLTING01
               BEGIN TRAN                       
               DELETE FROM dbo.PackHeader WITH (ROWLOCK) WHERE PickSlipNo = @c_PickHeaderKey AND [Status] < '9'    
                
               SET @n_err =  @@ERROR     
    
               IF @n_err <> 0    
               BEGIN    
                  SET @n_continue = 3      
                  SET @c_errmsg = ERROR_MESSAGE()    
                  SET @n_err = 551810    
                  SET @c_errmsg='NSQL'+CONVERT(char(6),@n_err)+': Delete Packheader fail. (lsp_Unallocation_Wrapper)' + ' ( SQLSvr MESSAGE=' + @c_errmsg + ' ) '     
               END 
               ELSE
               BEGIN
                  COMMIT TRAN                
               END                     
            END    
         END    
            
         IF @n_continue IN (1,2) AND EXISTS (SELECT 1 FROM dbo.PickHeader AS ph WITH (NOLOCK) WHERE ph.PickHeaderKey = @c_PickHeaderKey)    
         BEGIN
            --TLTING01
            BEGIN TRAN      
            DELETE dbo.PickHeader WITH (ROWLOCK) WHERE PickHeaderKey = @c_PickHeaderKey     
             
            IF @n_err <> 0    
            BEGIN    
               SET @n_continue = 3      
               SET @c_errmsg = ERROR_MESSAGE()    
               SET @n_err = 551811    
               SET @c_errmsg='NSQL'+CONVERT(char(6),@n_err)+': Delete PickHeader fail. (lsp_Unallocation_Wrapper)' + ' ( SQLSvr MESSAGE=' + @c_errmsg + ' ) '     
            END
            ELSE
            BEGIN
               COMMIT TRAN
            END                 
         END    
    
         FETCH NEXT FROM @CUR_DELPICKSLIP INTO @c_PickHeaderKey          
      END    
      CLOSE @CUR_DELPICKSLIP    
      DEALLOCATE @CUR_DELPICKSLIP    
      --(Wan03) - END    
        
   END TRY      
      
   BEGIN CATCH    
      SET @n_Continue = 3                       --(Wan01)    
      SET @c_ErrMsg = ERROR_MESSAGE()           --(Wan01)          
      GOTO EXIT_SP      
   END CATCH -- (SWT01) - End Big Outer Begin try.. end Try Begin Catch.. End Catch      
    
   EXIT_SP:     
  
   IF CURSOR_STATUS('GLOBAL','CUR_PICKDETAIL') >= 0         --KY01   
   BEGIN  
      CLOSE CUR_PICKDETAIL  
      DEALLOCATE CUR_PICKDETAIL  
   END  
       
   IF (XACT_STATE()) = -1      
   BEGIN    
      SET @n_Continue = 3     
      ROLLBACK TRAN    
   END      
       
   IF @n_continue=3  -- Error Occured - Process And Return      
   BEGIN      
      SELECT @b_success = 0      
      IF @n_starttcnt = 0 AND @@TRANCOUNT > @n_starttcnt          --(Wan02)               
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
      execute nsp_logerror @n_err, @c_errmsg, 'lsp_Unallocation_Wrapper'      
      --RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012 --(Wan01)      
      --RETURN                                                    --(Wan02)    
   END      
   ELSE      
   BEGIN      
      SELECT @b_success = 1      
      WHILE @@TRANCOUNT > @n_starttcnt      
      BEGIN      
         COMMIT TRAN      
      END      
      --RETURN                                                    --(Wan02)    
   END     
    
   WHILE @@TRANCOUNT < @n_starttcnt                               --(Wan02)    
   BEGIN    
      BEGIN TRAN    
   END                                                                
   REVERT                                                         --(Wan01) - Move Down                 
END    

GO