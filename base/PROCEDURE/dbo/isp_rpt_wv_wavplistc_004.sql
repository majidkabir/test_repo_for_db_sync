SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/***************************************************************************/                                            
/* Stored Procedure: isp_RPT_WV_WAVPLISTC_004                              */                                            
/* Creation Date: 16-NOV-2022                                              */                                            
/* Copyright: LFL                                                          */                                            
/* Written by: CHONGCS                                                     */                                            
/*                                                                         */                                            
/* Purpose: WMS-21137 JP BirkenStock BSJ Load Picking List                 */                                            
/*                                                                         */                                            
/* Called By: RPT_WV_WAVPLISTC_004                                         */                                            
/*                                                                         */                                            
/* GitLab Version: 1.0                                                     */                                            
/*                                                                         */                                            
/* Version: 1.0                                                            */                                            
/*                                                                         */                                            
/* Data Modifications:                                                     */                                            
/*                                                                         */                                            
/* Updates:                                                                */                                            
/* Date         Author  Ver   Purposes                                     */                                        
/* 16-NOV-2022  CHONGCS 1.0   DevOps Combine Script                        */                                 
/* 02-FEB-2023  CHONGCS 1.1   WMS-21636 revised logic (CS02)               */   
/* 13-Jun-2023  CHONGCS 1.2   Performance Tunning (CS03)                   */                            
/***************************************************************************/                                           
                                          
CREATE     PROC [dbo].[isp_RPT_WV_WAVPLISTC_004] (                                          
   @c_Wavekey           NVARCHAR(13) ,                                        
   @c_PreGenRptData     NVARCHAR(10) = ''                                        
)                                          
AS                                          
                                          
BEGIN                                          
   SET NOCOUNT ON                                             
   SET QUOTED_IDENTIFIER OFF                                             
   SET ANSI_NULLS OFF                                             
   SET CONCAT_NULL_YIELDS_NULL OFF                                            
                                           
DECLARE    @n_StartTCnt       INT                                          
         , @n_Continue        INT                                                     
         , @b_Success         INT                                          
         , @n_Err             INT                                          
         , @c_Errmsg          NVARCHAR(255)                                          
                                   
DECLARE                                
        @c_Xpickqty        NVARCHAR(10)                                        
       ,@c_YpickQty        NVARCHAR(10)                                  
       ,@c_loadkey         NVARCHAR(20)                       
       ,@c_PIPickslipno    NVARCHAR(20)                                        
       ,@c_GetPIPickslipno NVARCHAR(20)                                        
       ,@c_PAPickslipno    NVARCHAR(20)         
       ,@c_GetPAPickslipno NVARCHAR(20)                                        
       ,@c_UPPAPickslipno  NVARCHAR(20)                                        
       ,@n_pqty            INT                                        
       ,@n_ODqty           INT                                                     
       ,@n_ttlODqty        INT =0                                        
       ,@n_Xpickqty        INT =0                                      
       ,@n_YpickQty        INT                                                       
       ,@c_mergeorderkey   NVARCHAR(500)                                        
       ,@c_mergeExtOrdkey  NVARCHAR(500)                                        
       ,@n_rowctn          INT = 1                                        
       ,@n_Pickslipnoctn   INT = 1                                        
       ,@c_taskno          NVARCHAR(5)                                        
       ,@n_ctnrec          INT = 0                                        
       ,@c_newpickslip     NVARCHAR(1) = 'N'                                        
       ,@n_regrp           INT = 1                                        
       ,@n_psgrp           INT = 0                                        
       ,@n_ctnremaning     INT = 1                                                                        
       ,@c_Storerkey       NVARCHAR(15)                                                                             
       ,@c_PrnDateTime     NVARCHAR(16)                                                 
       ,@c_Sku             NVARCHAR(20)                                                                                                       
       ,@c_GetWavekey      NVARCHAR(10)                                        
       ,@n_TTLPQty         INT                                         
       ,@c_gettaskno       NVARCHAR(5)                         
       ,@c_prevsku         NVARCHAR(20)         --CS02                            
       ,@n_pqtybysku       INT                  --CS02                               
       ,@n_odqtybysku      INT                  --CS02                             
       ,@n_ttlskuqty       INT =0               --CS02                
       ,@c_GetPickslip     NVARCHAR(20)                
       ,@c_GetSKU          NVARCHAR(20)                
       ,@c_GetLoad         NVARCHAR(20)                
       ,@n_ctnsku          INT            
       ,@n_GetSUMSKUQtyByTask      INT             
              
       SET @n_StartTCnt  =  @@TRANCOUNT                                          
       SET @n_Continue   =  1                                                                       
       SET @c_Storerkey     = ''                                                                   
       SET @c_Sku           = ''                   
        
                                          
   WHILE @@TranCount > 0                                            
   BEGIN                                            
      COMMIT TRAN                                            
   END                               
                        
CREATE TABLE #ORDERS                                        
(                                                                     
   loadkey          NVARCHAR(20),          
   B_CONTACT1       NVARCHAR(200),          
   BUYERPO          NVARCHAR(40),          
   USERDEFINE10  NVARCHAR(20),          
   DeliveryDate  DATETIME          
)           
                                        
CREATE TABLE #TMPWAVPLISTC004H                                        
(  rowno            INT NOT NULL IDENTITY(1,1) PRIMARY KEY,                                                                     
   PIPickslipno     NVARCHAR(20),                                        
   PAPickslipno     NVARCHAR(20),                                
   Wavekey          NVARCHAR(20),                                        
   loadkey          NVARCHAR(20),          
   Orderkey         NVARCHAR(500),        
   ExtOrdkey        NVARCHAR(500),        
   sku              NVARCHAR(20),                                                              
   pqty             INT,                                        
   odqty            INT,                      
   Recgrp           INT,                                        
   psgrp            INT                                         
)                                        
                                      
CREATE TABLE #TMPWAVPLISTC004                                        
(  rowno            INT NOT NULL IDENTITY(1,1) PRIMARY KEY,                                        
   PIPickslipno     NVARCHAR(20),                                        
   PAPickslipno     NVARCHAR(20),                                 
   Wavekey          NVARCHAR(20),                                        
   loadkey          NVARCHAR(20),          
   Orderkey         NVARCHAR(500),        
   ExtOrdkey        NVARCHAR(500),        
   ctnsku           NVARCHAR(20),                                        
   qty              INT,                                        
   ttlpqty          INT,                                        
   ttlodqty         INT,                                        
   Xqty             INT,                                        
   Yqty             INT,                                        
   taskno           NVARCHAR(5)                                        
                                        
)                

--CS03 S
CREATE TABLE #TMPICKSUM                                        
(                                                                     
   Pickslipno            NVARCHAR(20),        
   CtnSku                INT,
   GetSUMSKUQtyByTask    INT         
) 

--CS03 E                        
                                        
            SELECT @c_storerkey = oh.storerkey                                        
            FROM orders oh WITH (NOLOCK)                                        
            WHERE oh.userdefine09 = @c_wavekey                                                
                                        
                                        
            SELECT @c_Xpickqty = c.Short                                        
            FROM dbo.CODELKUP C (NOLOCK)                                         
            WHERE c.LISTNAME='PickQty'                                        
            AND UPPER(c.Code)='X'                                        
            AND c.Storerkey=@c_storerkey                                        
                                        
                                        
            SELECT @c_Ypickqty = c.Short                                        
            FROM dbo.CODELKUP C (NOLOCK)                                         
            WHERE c.LISTNAME='PickQty'                                        
            AND UPPER(c.Code)='Y'                                        
            AND c.Storerkey=@c_storerkey                                        
                                        
                                        
            SET @n_Xpickqty = CAST (@c_Xpickqty AS INT)                                        
            SET @n_Ypickqty = CAST (@c_Ypickqty AS INT)                                        
                                          
                                                       
   WHILE @@TRANCOUNT > 0                                          
   BEGIN                                          
      COMMIT TRAN                                          
   END                                        
                                                                        
   SET @n_continue = 1               
                                                            
                                      
    DECLARE CUR_WAVELOAD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR                                         
    SELECT DISTINCT OH.UserDefine09,OH.LoadKey                                        
    FROM ORDERS OH WITH (NOLOCK)                                        
    WHERE OH.UserDefine09=@c_wavekey                                        
    AND ISNULL(OH.LoadKey,'') <> ''                                        
    ORDER BY OH.UserDefine09,OH.LoadKey                                        
                                        
    OPEN CUR_WAVELOAD                                        
                  
      FETCH NEXT FROM CUR_WAVELOAD INTO @c_Getwavekey,@c_loadkey                                        
      WHILE @@FETCH_STATUS = 0                                        
      BEGIN                                        
                                                     
      SET @n_ttlpqty = 0                            
      SET @n_ttlODqty = 0                                        
      SET @n_rowctn = 1                                                                       
      SET @c_prevsku = ''                     --CS02                        
                              
         --loop for sku qty > Xpickqty                                        
         DECLARE CUR_LOADPICK1 CURSOR LOCAL FAST_FORWARD READ_ONLY FOR                                         
            SELECT PH.PickHeaderKey,MAX(pd.PICKSLIPNO),pd.SKU        
            FROM ORDERS O (NOLOCK)                                        
            JOIN orderdetail od WITH (NOLOCK) ON od.OrderKey=o.orderkey                                        
            JOIN PICKDETAIL PD WITH (NOLOCK) ON (Od.ORDERKEY=PD.ORDERKEY AND od.OrderLineNumber = pd.OrderLineNumber AND od.Sku=pd.Sku AND od.StorerKey = pd.Storerkey)                                        
            LEFT JOIN dbo.PickHeader PH WITH (NOLOCK) ON PH.LoadKey=o.LoadKey                                     
            WHERE O.USERDEFINE09 =@c_Getwavekey and o.loadkey =@c_loadkey                
            AND ISNULL(PD.PICKHEADERKEY,'') = ''                     
            GROUP BY ph.PickHeaderKey,pd.SKU        
            HAVING   SUM(pd.qty) > @n_Xpickqty                                    
            ORDER BY pd.sku                                        
                                        
         OPEN CUR_LOADPICK1                                        
         FETCH NEXT FROM CUR_LOADPICK1 INTO @c_PAPickslipno,@c_PIPickslipno,@c_sku                                        
         WHILE @@FETCH_STATUS = 0                                       
         BEGIN                                        
                
            SET @n_ttlskuqty = 0   --CS02 S                
                
            SELECT @n_ttlskuqty = sum(qty)                
            FROM pickdetail pd WITH (NOLOCK)                
            JOIN orders o WITH (NOLOCK) ON (pd.orderkey=o.orderkey)                 
            WHERE o.UserDefine09=@c_Getwavekey AND o.LoadKey = @c_loadkey AND pd.Sku = @c_sku                   
                       
                      
            IF NOT EXISTS (SELECT 1 FROM PICKHEADER (NOLOCK)                                         
            WHERE wavekey      = @c_GetWavekey AND ISNULL(loadkey,'')='' ) AND ISNULL(@c_PIPickslipno,'') = ''                                         
            AND @c_PreGenRptData = 'Y' AND (@n_rowctn='1' OR @c_prevsku <> @c_Sku)    --Draft fix GDF01                                        
                    
            BEGIN                                         
               EXECUTE nspg_GetKey                                               
               'PICKSLIP'                                            
               ,  9                                            
               ,   @c_PIPickslipno OUTPUT                                            
               ,  @b_Success    OUTPUT                                            
               ,  @n_err        OUTPUT                           
               ,  @c_errmsg     OUTPUT                                                  
                                                                     
               SET  @c_PIPickslipno = 'P' +  @c_PIPickslipno                                              
            END                                        
                                     
            IF ISNULL(@c_PAPickslipno,'') = ''                                        
            BEGIN                                         
               SET @c_PAPickslipno = ''                                        
            END                                         
                     
            
            --CS02 S                        
            IF @c_prevsku <> @c_Sku                         
            BEGIN                                      
             SET @c_taskno = RIGHT('00000' + RTRIM(CAST(RTRIM(@n_rowctn) AS NCHAR(5))),5)             
             SET @n_psgrp = @n_psgrp + 1            
            END                   
                
            IF @c_prevsku = @c_Sku        --GDF01             
            BEGIN                                        
             Select @c_PIPickslipno =PIPickslipno from #TMPWAVPLISTC004H where sku =@c_Sku                
            END                          
                
                     INSERT INTO #TMPWAVPLISTC004H                                         
                     (                                                                       
                         PIPickslipno,                                
                         PAPickslipno,                                        
                         Wavekey,                                        
                         loadkey,         
                         Orderkey,          
                         ExtOrdkey,        
                         sku,                                                            
                         pqty,                                        
                         odqty,                                        
                         Recgrp,psgrp                                        
                     )                                        
                     VALUES                                        
                         (@c_PIPickslipno,@c_PAPickslipno,@c_Getwavekey,@c_loadkey,'','',@c_sku,'','',@n_rowctn,@n_psgrp)                                        
                                        
                                        
               INSERT INTO #TMPWAVPLISTC004                                         
               (                                        
                  PIPickslipno,                                        
                  PAPickslipno,                                        
                  Wavekey,                                        
                  loadkey,        
                  Orderkey,          
                  ExtOrdkey,        
                  ctnsku,                                        
                  qty,                                        
                  ttlpqty,                                        
                  ttlodqty,                                        
                  Xqty,                                        
                  Yqty,                                        
                  taskno                                          
               )                                        
               VALUES                                        
               (@c_PIPickslipno,@c_PAPickslipno,@c_Getwavekey,@c_loadkey,'','',1,'',@n_ttlpqty,@n_ttlODqty,@n_Xpickqty,@n_YpickQty,@c_taskno)                                        
                                        
                   
                  IF @c_prevsku <> @c_Sku                         
                  BEGIN                        
                     SET @n_rowctn = @n_rowctn + 1                            
                  END         
                          
               SET @c_prevsku = @c_sku                                                     
                                       
                   
         FETCH NEXT FROM CUR_LOADPICK1 INTO @c_PAPickslipno,@c_PIPickslipno,@c_sku                                        
         END                                        
         CLOSE CUR_LOADPICK1                                        
         DEALLOCATE CUR_LOADPICK1                                        
                                                        
         SET @n_ttlpqty = 0                                        
         SET @n_ttlODqty = 0                                                                 
         SET @n_Pickslipnoctn = @n_rowctn     --CS02                                    
         SET @c_mergeExtOrdkey = ''                                        
         SET @c_mergeExtOrdkey = ''                                        
         SET @c_taskno = '00000'                         
         SET @n_ctnrec = 1                                        
         SET @c_newpickslip = 'N'                                                                                       
         SET @n_ctnremaning = 0                                
         SET @c_prevsku = ''                       --CS02         
         SET @n_rowctn = 1             
         SET @n_regrp =0            
                                        
         --loop for sku qty <= Xpickqty                                    
         DECLARE CUR_LOADPICK2 CURSOR LOCAL FAST_FORWARD READ_ONLY FOR                                         
            SELECT ph.PickHeaderKey,MAX(pd.PICKSLIPNO),pd.SKU        
            FROM ORDERS O WITH (NOLOCK)                                        
            JOIN orderdetail od (NOLOCK) ON od.OrderKey=o.orderkey                                        
            JOIN PICKDETAIL PD WITH (NOLOCK)ON (Od.ORDERKEY=PD.ORDERKEY AND od.OrderLineNumber = pd.OrderLineNumber AND od.Sku=pd.Sku AND od.StorerKey = pd.Storerkey)                                        
            LEFT JOIN dbo.PickHeader PH WITH (NOLOCK) ON PH.LoadKey=o.LoadKey                                        
            WHERE O.USERDEFINE09 =@c_Getwavekey and o.loadkey =@c_loadkey                                      
            AND ISNULL(PD.PICKHEADERKEY,'') = ''                     
            GROUP BY ph.PickHeaderKey,pd.SKU                         
            HAVING   SUM(pd.qty) <= @n_Xpickqty                                         
            ORDER BY pd.sku   --G01                                      
                                        
         OPEN CUR_LOADPICK2                                        
         FETCH NEXT FROM CUR_LOADPICK2 INTO @c_PAPickslipno,@c_PIPickslipno,@c_sku                                        
         WHILE @@FETCH_STATUS = 0                                        
         BEGIN                                        
                                      
            SET @n_ttlskuqty = 0            
                
            SELECT @n_ttlskuqty = sum(qty)                
            FROM pickdetail pd WITH (NOLOCK)                
            JOIN orders o WITH (NOLOCK) ON (pd.orderkey=o.orderkey)                 
            WHERE o.UserDefine09=@c_Getwavekey AND o.LoadKey = @c_loadkey AND pd.Sku = @c_sku                
                           
        
            SELECT @n_ctnrec = COUNT(PD.sku)         
            FROM ORDERS O WITH (NOLOCK)                                        
            JOIN orderdetail od (NOLOCK) ON od.OrderKey=o.orderkey                                        
            JOIN PICKDETAIL PD WITH (NOLOCK) ON (Od.ORDERKEY=PD.ORDERKEY AND od.OrderLineNumber = pd.OrderLineNumber AND od.Sku=pd.Sku AND od.StorerKey = pd.Storerkey)                                        
            WHERE O.USERDEFINE09 =@c_Getwavekey and o.loadkey =@c_loadkey and pd.qty <= @n_Xpickqty         
            AND pd.sku = @c_sku                              
                                        
            SELECT @n_ctnremaning = COUNT(sku)                  
            FROM #TMPWAVPLISTC004H                                         
            WHERE wavekey=@c_getwavekey AND loadkey = @c_loadkey AND pqty <=@n_Xpickqty AND sku = @c_sku                                       
        
            IF (@n_rowctn = 1 OR  @n_rowctn > @n_YpickQty ) AND   @c_prevsku <> @c_Sku           
            BEGIN                                        
                  SET  @c_newpickslip = 'Y'                                                                   
                  SET @n_psgrp = @n_psgrp + 1               
                  SET @n_regrp = @n_regrp + 1         
                  IF @n_rowctn > @n_YpickQty        
                  BEGIN        
                     SET @n_rowctn = 1        
                  END        
            END                  
                     
            INSERT INTO #TMPWAVPLISTC004H                                         
            (                                                                      
               PIPickslipno,                                        
               PAPickslipno,                                        
               Wavekey,                                        
               loadkey,        
               Orderkey,          
               ExtOrdkey,        
               sku,                                                                
               pqty,                                        
               odqty,                                        
               Recgrp,psgrp                                        
            )                                        
            VALUES                                        
            (@c_PIPickslipno,@c_PAPickslipno,@c_Getwavekey,@c_loadkey,'','',@c_sku,'','',@n_regrp,@n_psgrp)                        
              
                IF @c_newpickslip = 'Y'                                        
                BEGIN                                 
                        
                 SET @n_pqtybysku = 0      --CS02                        
                 SET @n_odqtybysku = 0     --CS02                        
                             
                    IF NOT EXISTS (SELECT 1 FROM PICKHEADER (NOLOCK)               
                                   WHERE wavekey      = @c_GetWavekey AND ISNULL(loadkey,'')='') AND ISNULL(@c_PIPickslipno,'') = ''                        
                                   AND @c_PreGenRptData = 'Y'                                         
                    BEGIN                                         
                                             
                       EXECUTE nspg_GetKey                                        
                       'PICKSLIP'                                            
                       ,  9                               
                       ,  @c_PIPickslipno OUTPUT                                            
                       ,  @b_Success    OUTPUT                                            
                       ,  @n_err        OUTPUT                                            
                       ,  @c_errmsg     OUTPUT                                                  
                                                                          
                       SET  @c_PIPickslipno = 'P' +  @c_PIPickslipno         
                            
                    END                                        
                                             
                    IF ISNULL(@c_PAPickslipno,'') = ''                                        
                    BEGIN                              
                       SET @c_PAPickslipno = ''                                        
                    END                                         
                                             
                    SET @c_taskno = RIGHT('00000' + RTRIM(CAST(RTRIM(@n_Pickslipnoctn) AS NCHAR(5))),5)                                        
                                              
                    UPDATE #TMPWAVPLISTC004H      
                    SET PIPickslipno = @c_PIPickslipno                                        
                    WHERE Wavekey = @c_Getwavekey AND loadkey=@c_loadkey AND Recgrp =@n_regrp AND psgrp =@n_psgrp AND sku = @c_Sku    --Cs02                
                             
                    SELECT @n_pqtybysku  = SUM(pqty)                        
                         ,@n_odqtybysku = SUM(odqty)                        
                    FROM #TMPWAVPLISTC004H                         
                    WHERE PIPickslipno = @c_PIPickslipno                         
                                                                        
                         INSERT INTO #TMPWAVPLISTC004                                         
       (                                        
                             PIPickslipno,                                        
                             PAPickslipno,                      
                             Wavekey,                                        
                             loadkey,        
                             Orderkey,          
                             ExtOrdkey,        
                             ctnsku,                                        
                             qty,                                        
                             ttlpqty,                                        
                             ttlodqty,                                        
                             Xqty,                                        
                             Yqty,                                        
                             taskno                                        
                         )                                        
                         VALUES                                        
                         (@c_PIPickslipno, @c_PAPickslipno,@c_Getwavekey,@c_loadkey,'','',@n_rowctn,@n_pqtybysku,@n_ttlpqty,@n_ttlODqty,@n_Xpickqty,@n_YpickQty,@c_taskno)                                        
                                                                                      
                         SET @n_Pickslipnoctn = @n_Pickslipnoctn + 1                                           
                         SET @c_taskno = ''                                        
                         SET @c_newpickslip = 'N'                                        
                     END                  
                     ELSE                 
                     BEGIN                                       
                            
                         IF @n_rowctn <>1            
                         BEGIN            
                            Select @c_PIPickslipno =PIPickslipno from #TMPWAVPLISTC004H where psgrp =@n_psgrp  AND  ISNULL(PIPickslipno,'') <> ''             
                                 
                            UPDATE #TMPWAVPLISTC004H                                                                
                            SET PIPickslipno = @c_PIPickslipno                                        
                            WHERE Wavekey = @c_Getwavekey AND loadkey=@c_loadkey AND Recgrp =@n_regrp AND psgrp =@n_psgrp AND  ISNULL(PIPickslipno,'') = ''                        
                         END            
                     END                                                                
                             
                     IF @c_prevsku <> @c_Sku                         
                     BEGIN                        
                          SET @n_rowctn = @n_rowctn + 1                               
                     END                                                   
                             
                     SET @c_prevsku = @c_sku     --CS02                         
                        
            FETCH NEXT FROM CUR_LOADPICK2 INTO @c_PAPickslipno,@c_PIPickslipno,@c_sku                                        
            END               
            CLOSE CUR_LOADPICK2                                        
            DEALLOCATE CUR_LOADPICK2                                        
                     
         SET @c_GetPAPickslipno = ''                                        
         SET @n_TTLPQty = 0                    
         SET @n_ttlODqty = 0              
                 
            SELECT @c_GetPAPickslipno = ISNULL(PAPickslipno,'')                                        
            FROM #TMPWAVPLISTC004H                                         
            WHERE Wavekey = @c_Getwavekey AND loadkey =@c_loadkey                                                  
                                    
            IF NOT EXISTS (SELECT 1 FROM PICKHEADER (NOLOCK)                                         
                            WHERE ISNULL(loadkey,'')= @c_loadkey AND PickHeaderKey LIKE 'D%') AND ISNULL(@c_GetPAPickslipno,'') = ''                                         
                            AND @c_PreGenRptData = 'Y'                                         
            BEGIN                                        
                                        
            EXECUTE nspg_GetKey                                               
            'PICKSLIP'                                            
            ,  9                                            
            ,  @c_GetPAPickslipno OUTPUT                                            
            ,  @b_Success         OUTPUT                                            
            ,  @n_err             OUTPUT                                            
            ,  @c_errmsg          OUTPUT                                                  
                                                                     
                SET  @c_GetPAPickslipno = 'D' +  @c_GetPAPickslipno                                              
                                                      
                UPDATE #TMPWAVPLISTC004H                                         
                SET PAPickslipno = @c_GetPAPickslipno                                        
                WHERE Wavekey = @c_Getwavekey AND loadkey =@c_loadkey AND sku = @c_sku        --CS02a                                            
                                        
                UPDATE #TMPWAVPLISTC004                                         
                SET PAPickslipno = @c_GetPAPickslipno                                        
                WHERE Wavekey = @c_Getwavekey AND loadkey =@c_loadkey                                   
                       
         END                                        
                                        
                                                         
         SET @c_mergeExtOrdkey =            
         (SELECT STUFF((SELECT distinct RTRIM(OH.externorderkey)+', 'FROM ORDERS OH (NOLOCK) where OH.LoadKey=@c_loadkey  FOR XML PATH('')),1,0,''))            
                                        
         SET @c_mergeorderkey  =             
         (SELECT STUFF((SELECT distinct RTRIM(OH.orderkey)+', 'FROM ORDERS OH (NOLOCK) where OH.LoadKey=@c_loadkey  FOR XML PATH('')),1,0,''))                                            
                       
         SELECT @n_TTLPQty = SUM(PD.QTY) FROM ORDERS O (NOLOCK) JOIN PICKDETAIL PD (NOLOCK) ON (O.ORDERKEY=PD.ORDERKEY)            
         WHERE O.USERDEFINE09 = @C_GETWAVEKEY AND O.LOADKEY =@C_LOADKEY             
              
         SELECT @n_ttlODqty = SUM(OD.OriginalQty) FROM ORDERS O (NOLOCK) JOIN ORDERDETAIL OD (NOLOCK) ON (O.ORDERKEY=OD.ORDERKEY)            
         WHERE O.USERDEFINE09 = @C_GETWAVEKEY AND O.LOADKEY =@C_LOADKEY                
        
         UPDATE #TMPWAVPLISTC004H         
            SET Orderkey = @c_mergeorderkey         
               ,ExtOrdkey = @c_mergeExtOrdkey         
         WHERE Wavekey = @c_Getwavekey AND loadkey =@c_loadkey             
              
         UPDATE #TMPWAVPLISTC004                       
            SET  ttlpqty = @n_TTLPQty                                        
                ,ttlodqty = @n_ttlODqty                                        
                ,Orderkey = @c_mergeorderkey                                        
                ,ExtOrdkey = @c_mergeExtOrdkey                                        
         WHERE Wavekey = @c_Getwavekey AND loadkey =@c_loadkey                                        
                                        
      FETCH NEXT FROM CUR_WAVELOAD INTO @c_Getwavekey,@c_loadkey                                        
      END                                        
      CLOSE CUR_WAVELOAD                                        
      DEALLOCATE CUR_WAVELOAD                                         
              
   IF @c_PreGenRptData = 'Y'                                        
   BEGIN                                        
       DECLARE CUR_INSERTPICKPACKTBL CURSOR LOCAL FAST_FORWARD READ_ONLY FOR                                
         SELECT DISTINCT PIPickslipno,PAPickslipno,loadkey,Wavekey,taskno             
         FROM #TMPWAVPLISTC004                                        
         WHERE Wavekey=@c_Wavekey                                        
         ORDER BY PIPickslipno                                        
                                        
      OPEN CUR_INSERTPICKPACKTBL                                        
      FETCH NEXT FROM CUR_INSERTPICKPACKTBL INTO @c_GetPIPickslipno,@c_UPPAPickslipno,@c_loadkey,@c_GetWavekey,@c_gettaskno                                        
      WHILE @@FETCH_STATUS = 0                                        
      BEGIN                                        
                                                              
      IF NOT EXISTS (SELECT 1 FROM dbo.PICKHEADER WITH (NOLOCK)         
                     WHERE PickHeaderKey = @c_GetPIPickslipno and wavekey =@c_GetWavekey and ConsoOrderKey=@c_loadkey+' '+@c_gettaskno )                  
             AND ISNULL(@c_GetPIPickslipno,'') <> ''                                     
      BEGIN                                                
         INSERT INTO PICKHEADER (PickHeaderKey, WaveKey, Orderkey,ConsoOrderKey, PickType, Zone, TrafficCop )                                              
         VALUES (@c_GetPIPickslipno ,@c_GetWavekey, '',@c_loadkey+' '+@c_gettaskno, '0', '', '')                                          
                                        
             SELECT @n_err = @@ERROR                                              
             IF @n_err <> 0                                              
             BEGIN                                              
                SELECT @n_continue = 3                                              
                SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 81110   -- Should Be Set To The SQL Errmessage but I don't know how to do so.                                              
                SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert PICKHEADER Failed (isp_RPT_WV_WAVPLISTC_004)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '                                          
                   
                 GOTO QUIT                                            
             END                                               
                                             
      END                                        
                                        
      IF NOT EXISTS (SELECT 1 FROM dbo.PICKHEADER WITH (NOLOCK)         
      WHERE PickHeaderKey = @c_UPPAPickslipno AND LoadKey = @c_Loadkey) AND ISNULL(@c_GetPIPickslipno,'') <> ''         
      BEGIN                                        
                    
         INSERT INTO PICKHEADER (PickHeaderKey, WaveKey, Orderkey,ExternOrderKey, PickType, Zone, TrafficCop,LoadKey,ConsoOrderKey)                                                  
         VALUES (@c_UPPAPickslipno , '', '',@c_loadkey, '0', '', '',@c_loadkey,@c_loadkey+' '+@c_gettaskno)   --G01                                          
                                          
         INSERT INTO PACKHEADER (PickSlipno,Storerkey,Orderkey,LoadKey)                                                  
         VALUES (@c_UPPAPickslipno ,@c_Storerkey, '',@c_loadkey)   --G01                                          
                                        
             SELECT @n_err = @@ERROR                                              
             IF @n_err <> 0                                              
             BEGIN                                              
                SELECT @n_continue = 3                                              
                SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 81120  -- Should Be Set To The SQL Errmessage but I don't know how to do so.                                              
                SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert PACKHEADER Failed (isp_RPT_WV_WAVPLISTC_004)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '                                          
                                        
                 GOTO QUIT                                            
             END                                                                        
      END                                                                               
                                        
      FETCH NEXT FROM CUR_INSERTPICKPACKTBL INTO @c_GetPIPickslipno,@c_UPPAPickslipno,@c_loadkey,@c_GetWavekey,@c_gettaskno                                        
      END                                        
      CLOSE CUR_INSERTPICKPACKTBL                                        
      DEALLOCATE CUR_INSERTPICKPACKTBL                      
                                       
    END                            
                  
        
      DECLARE CUR_UpdatePSNTBL1 CURSOR LOCAL FAST_FORWARD READ_ONLY FOR                   
      SELECT PIPickslipno,loadkey,sku FROM #TMPWAVPLISTC004H                   
            
      OPEN CUR_UpdatePSNTBL1                                        
      FETCH NEXT FROM CUR_UpdatePSNTBL1 INTO @c_GetPickslip,@c_GetLoad,@c_GetSKU                                        
      WHILE @@FETCH_STATUS = 0                                        
      BEGIN               
    
             IF @c_PreGenRptData = 'Y'                                        
             BEGIN           
                 
               UPDATE PICKDETAIL WITH (ROWLOCK)                                            
                  SET  PickSlipNo = @c_GetPickslip            
                      ,EditWho = SUSER_NAME()                                          
                      ,EditDate = GETDATE()                                           
                      ,TrafficCop = NULL                                           
               FROM Orders   O WITH (NOLOCK)                                          
               JOIN PICKDETAIL PD ON (O.Orderkey = PD.Orderkey)                                       
               WHERE ISNULL(PD.PickSlipNo,'') = '' AND O.loadkey = @c_GetLoad AND PD.SKU = @c_GetSKU            
            END        
    

      FETCH NEXT FROM CUR_UpdatePSNTBL1 INTO @c_GetPickslip,@c_GetLoad,@c_GetSKU                                        
      END                                        
      CLOSE CUR_UpdatePSNTBL1                                        
      DEALLOCATE CUR_UpdatePSNTBL1     


     --CS03 S
     INSERT INTO #TMPICKSUM
     (
         Pickslipno,
         CtnSku,
         GetSUMSKUQtyByTask
     )
      SELECT PICKSLIPNO, COUNT(Distinct SKU),  SUM(QTY) 
      FROM   PICKDETAIL   (NOLOCK)   
      WHERE  exists ( SELECT 1 FROM #TMPWAVPLISTC004H A WHERE A.PIPickslipno = PICKDETAIL.PICKSLIPNO  )  
      GROUP BY PICKSLIPNO


     --CS03 E            
               
      DECLARE CUR_UpdatePSNTBL2 CURSOR LOCAL FAST_FORWARD READ_ONLY FOR                   
      SELECT B.PIPickslipno,B.loadkey,B.sku, A.CtnSku,A.GetSUMSKUQtyByTask           --CS03 
      FROM #TMPWAVPLISTC004H B  
      JOIN #TMPICKSUM A on A.PICKSLIPNO = B.PIPickslipno              
            
      OPEN CUR_UpdatePSNTBL2                                        
      FETCH NEXT FROM CUR_UpdatePSNTBL2 INTO @c_GetPickslip,@c_GetLoad,@c_GetSKU , @n_ctnsku , @n_GetSUMSKUQtyByTask   --CS03                                       
      WHILE @@FETCH_STATUS = 0                                        
      BEGIN                
         --CS03 S  
         --SELECT @n_ctnsku = COUNT(Distinct SKU) FROM PICKDETAIL (NOLOCK) WHERE PICKSLIPNO = @c_GetPickslip                 
         --SELECT @n_GetSUMSKUQtyByTask = SUM(QTY) FROM PICKDETAIL (NOLOCK) WHERE PICKSLIPNO = @c_GetPickslip            
         --CS03 E
          --SELECT @c_GetPickslip '@c_GetPickslip',@n_ctnsku '@n_ctnsku',@n_GetSUMSKUQtyByTask '@n_GetSUMSKUQtyByTask'        
                 
         UPDATE #TMPWAVPLISTC004         
         SET  QTY = @n_GetSUMSKUQtyByTask        
             ,ctnsku = @n_ctnsku           
         WHERE PIPickslipno = @c_GetPickslip            
            
      FETCH NEXT FROM CUR_UpdatePSNTBL2 INTO @c_GetPickslip,@c_GetLoad,@c_GetSKU, @n_ctnsku , @n_GetSUMSKUQtyByTask   --CS03                                     
      END                                        
      CLOSE CUR_UpdatePSNTBL2                                        
      DEALLOCATE CUR_UpdatePSNTBL2             
                                    
   GOTO QUIT                                            
                                             
QUIT:                                          
                                            
                                          
   IF @n_Continue=3  -- Error Occured - Process And Return                                
   BEGIN                                           
      IF @@TRANCOUNT > @n_StartTCnt                     
      BEGIN                                            
         ROLLBACK TRAN                                            
      END                                           
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'isp_RPT_WV_WAVPLISTC_004'                                   
   END                                          
                                   
   IF ISNULL(@c_PreGenRptData,'') = ''                                        
   BEGIN                             
          
      SET @c_PrnDateTime = CONVERT(NVARCHAR(10),GETDATE(),111)+ SPACE(1)+ CONVERT(NVARCHAR(6),GETDATE(),24)                 
          
      INSERT INTO #Orders (loadkey,DeliveryDate,B_CONTACT1,BUYERPO,USERDEFINE10)           
      SELECT LOADKEY,MAX(DELIVERYDATE),MAX(B_CONTACT1),MAX(BUYERPO),MAX(USERDEFINE10) FROM ORDERS  (NOLOCK) WHERE USERDEFINE09 =@c_Wavekey          
      GROUP BY LOADKEY          
          
      SELECT          
      A.PIPICKSLIPNO AS PICKSLIPNO,A.PAPickslipno AS PACKSLIPNO,A.WAVEKEY,A.LOADKEY,          
      A.ORDERKEY,A.EXTORDKEY,          
      A.QTY,A.ttlpqty AS ttlpty,A.ttlodqty AS ttlordqty,A.XQTY,A.YQTY,          
      A.taskno as 'gettaskno',A.ctnsku,CONVERT(NVARCHAR(10),o.DeliveryDate,111) AS DELDATE,ISNULL(o.B_contact1,'') AS BContact1           
      ,ISNULL(o.BuyerPO,'')AS Buyerpo,CASE WHEN ISNULL(o.UserDefine10,'') ='Q01' THEN 'Y' ELSE 'N' End AS 'VAS',@c_PrnDateTime AS PrnDatetime          
      FROM #TMPWAVPLISTC004 A Join #Orders O on (A.loadkey=o.loadkey)          
          
   END                                        
            
                                        
 IF OBJECT_ID('tempdb..#ORDERS') IS NOT NULL                                        
  DROP TABLE #ORDERS               
             
 IF OBJECT_ID('tempdb..#TMPWAVPLISTC004H') IS NOT NULL                                        
  DROP TABLE #TMPWAVPLISTC004H                                        
                                        
   IF OBJECT_ID('tempdb..#TMPWAVPLISTC004') IS NOT NULL                                        
      DROP TABLE #TMPWAVPLISTC004                

--CS03 S
   IF OBJECT_ID('tempdb..#TMPICKSUM') IS NOT NULL                                        
      DROP TABLE #TMPICKSUM  
--CS03 E                        
                                        
                                        
   IF CURSOR_STATUS('LOCAL' , 'CUR_WAVELOAD') in (0 , 1)                                        
   BEGIN                                        
      CLOSE CUR_WAVELOAD                                        
      DEALLOCATE CUR_WAVELOAD                                           
   END                             
                
                
   IF CURSOR_STATUS('LOCAL' , 'CUR_UpdateXPICKPACKTBL') in (0 , 1)          
   BEGIN                     
      CLOSE CUR_UpdateXPICKPACKTBL                                        
      DEALLOCATE CUR_UpdateXPICKPACKTBL                                           
   END                             
                                        
                                        
   IF CURSOR_STATUS('LOCAL' , 'CUR_LOADPICK1') in (0 , 1)                                        
   BEGIN                                        
      CLOSE CUR_LOADPICK1                                        
      DEALLOCATE CUR_LOADPICK1                                           
   END                                        
                              
                                        
   IF CURSOR_STATUS('LOCAL' , 'CUR_LOADPICK2') in (0 , 1)                                        
   BEGIN                                        
      CLOSE CUR_LOADPICK2                                        
      DEALLOCATE CUR_LOADPICK2                                           
   END                                        
                                        
   IF CURSOR_STATUS('LOCAL' , 'CUR_INSERTPICKPACKTBL') in (0 , 1)                                        
   BEGIN                                        
      CLOSE CUR_INSERTPICKPACKTBL                                        
      DEALLOCATE CUR_INSERTPICKPACKTBL                                           
   END                    
                    
   IF CURSOR_STATUS('LOCAL' , 'CUR_UpdatePSNTBL1') in (0 , 1)                                        
   BEGIN                                        
      CLOSE CUR_UpdatePSNTBL1                                        
      DEALLOCATE CUR_UpdatePSNTBL1               
   END                       
                
   IF CURSOR_STATUS('LOCAL' , 'CUR_UpdatePSNTBL2') in (0 , 1)                                        
   BEGIN                                        
      CLOSE CUR_UpdatePSNTBL2                                       
      DEALLOCATE CUR_UpdatePSNTBL2                                          
   END                
                                  
   WHILE @@TRANCOUNT < @n_StartTCnt                                          
   BEGIN                                          
      BEGIN TRAN                                           
   END                                   
                                    
   RETURN                                          
QUIT_SP:                                        
END                                 
  

GO