SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/      
/* Store Procedure: ISP_RPT_WV_WAVPICKSUM_002                           */      
/* Creation Date: 27-OCT-2022                                           */      
/* Copyright:                                                           */      
/* Written by: CSCHONG                                                  */      
/*                                                                      */      
/* Purpose: WMS-21054 [TW] SHDEC WM Report WAVPICKSUM_CR                */      
/*                                                                      */      
/* Called By: RPT_WV_WAVPICKSUM_002                                     */      
/*                                                                      */      
/* PVCS Version: 1.1                                                    */      
/*                                                                      */      
/* Version: 5.4                                                         */      
/*                                                                      */      
/* Data Modifications:                                                  */      
/*                                                                      */      
/* Updates:                                                             */      
/*  Date         Author    Ver.  Purposes                               */  
/*  27-OCT-2022  CHONGCS   1.0   Devops Scripts Combine                 */ 
/*  22-MAY-2023  WZPang    1.1   WMS-22456                              */
/************************************************************************/      
    
CREATE   PROC [dbo].[ISP_RPT_WV_WAVPICKSUM_002] (
                            @c_wavekey NVARCHAR(10)
                          , @c_PreGenRptData NVARCHAR(10) = ''  )       
 AS      
 BEGIN      
 SET NOCOUNT ON       
 SET ANSI_NULLS OFF  
 SET QUOTED_IDENTIFIER OFF       
 SET CONCAT_NULL_YIELDS_NULL OFF     
   
    
  DECLARE @c_pickheaderkey        NVARCHAR(10),      
    @n_continue             int,      
    @c_errmsg               NVARCHAR(255),      
    @b_success              int,      
    @n_err                  int,      
    @n_pickslips_required   int ,  
    @n_starttcnt            INT,  
    @c_FirstTime            NVARCHAR(1),  
    @c_PrintedFlag          NVARCHAR(1),  
    @c_PickSlipNo           NVARCHAR(20),  
    @c_storerkey            NVARCHAR(20),
    @c_CNT                  NVARCHAR(10)
    
   SELECT @n_starttcnt=@@TRANCOUNT, @n_continue=1, @b_success=0, @n_err=0, @c_errmsg=''  
     
     
 CREATE TABLE #TEMP_WAVPICKSUM002  
  ( OrderKey          NVARCHAR(10) NULL,  
  WaveKey           NVARCHAR(10) NULL,  --   
  Qty               INT,     
  Pickheaderkey     NVARCHAR(20) NULL,      
  Storerkey         NVARCHAR(20) NULL,
  PLOC              NVARCHAR(10),
  SKU               NVARCHAR(20),
  SDESCR            NVARCHAR(80),
  LOTT02            NVARCHAR(18),
  LOTT03            NVARCHAR(18),
  LOTT04            NVARCHAR(10), 
  Loadkey           NVARCHAR(10),
  AddDate           DATE,         --WZ01
  RETAILSKU         NVARCHAR(20), --WZ01
  C01               NVARCHAR(20)  --WZ01
  )  
  
    
   -- Check if wavekey existed  
 IF EXISTS(SELECT 1 FROM PICKHEADER (NOLOCK)  
     WHERE WaveKey = @c_wavekey  
     AND   Zone = '8')  
 BEGIN  
  SELECT @c_FirstTime = N'N'  
  SELECT @c_PrintedFlag = N'Y'  
 END  
 ELSE  
 BEGIN  
  SELECT @c_FirstTime = N'Y'  
  SELECT @c_PrintedFlag = N'N'  
 END  

  IF @c_PreGenRptData = 'Y'  
  BEGIN   
       BEGIN TRAN  
       -- Uses PickType as a Printed Flag  
       UPDATE PICKHEADER WITH (ROWLOCK)  
       SET PickType = '1',  
         TrafficCop = NULL  
       WHERE WaveKey = @c_wavekey  
       AND Zone = '8'  
       AND PickType = '0'  
  
       SELECT @n_err = @@ERROR  
         IF @n_err <> 0  
         BEGIN  
            SELECT @n_continue = 3  
            IF @@TRANCOUNT >= 1  
            BEGIN  
               ROLLBACK TRAN  
               GOTO FAILURE  
            END  
         END  
         ELSE  
         BEGIN  
            IF @@TRANCOUNT > 0  
            BEGIN  
               COMMIT TRAN  
            END  
            ELSE  
            BEGIN  
               SELECT @n_continue = 3  
               ROLLBACK TRAN  
               GOTO FAILURE  
            END  
         END    
   END 
 
    
  INSERT INTO #TEMP_WAVPICKSUM002  
  SELECT   
            ORDERS.OrderKey AS Orderkey,  
            wave.wavekey AS Wavekey,    
            SUM(PICKD.qty) AS Qty,  
            (SELECT PICKHEADER.PickHeaderKey FROM PICKHEADER (NOLOCK)  
            WHERE PICKHEADER.Wavekey = @c_wavekey  
            AND PICKHEADER.OrderKey = ORDERS.OrderKey  
            AND PICKHEADER.ZONE = '8')   
            ,ORDERS.storerkey AS Storerkey 
            ,PICKD.Loc AS loc  
            ,PICKD.sku AS sku  
            ,sku.DESCR AS sdescr  
            ,ISNULL(LOTT.Lottable02,'') AS LOTT02
            ,ISNULL(LOTT.Lottable03,'') AS LOTT03
            ,CONVERT(NVARCHAR(10),LOTT.Lottable04,111) AS LOTT04   
            --,LOADPLANDETAIL.LoadKey                    --WZ01
            , (SELECT top 1 LOADPLANDETAIL.Loadkey FROM LOADPLANDETAIL(NOLOCK) WHERE LOADPLANDETAIL.LoadKey = Orders.LoadKey)
            ,WAVE.AddDate                                --WZ01
            ,SKU.RETAILSKU                               --WZ01
            ,C01 = ISNULL(RTRIM(C01.UDF05),'')           --WZ01
         FROM ORDERS (NOLOCK)    
         JOIN ORDERDETAIL OD WITH (NOLOCK) ON OD.OrderKey=ORDERS.orderkey
         JOIN WAVEDETAIL (NOLOCK) ON WAVEDETAIL.OrderKey = ORDERS.OrderKey   
         JOIN WAVE (NOLOCK) ON WAVE.WaveKey = WAVEDETAIL.WaveKey   
         JOIN SKU (NOLOCK) ON SKU.StorerKey = OD.StorerKey AND SKU.SKU = OD.SKU   
         JOIN dbo.PICKDETAIL PICKD WITH (NOLOCK) ON PICKD.OrderKey = OD.OrderKey AND PICKD.OrderLineNumber = OD.OrderLineNumber 
                                                AND PICKD.Storerkey = OD.StorerKey AND PICKD.sku = OD.sku
         JOIN dbo.LOTATTRIBUTE LOTT WITH (NOLOCK) ON LOTT.lot=PICKD.lot 
         LEFT JOIN CODELKUP C01 WITH (NOLOCK) ON C01.ListName= 'PLATFORM' AND C01.CODE = ORDERS.ConsigneeKey AND C01.Storerkey = ORDERS.StorerKey
         WHERE wave.WaveKey = @c_wavekey   
         GROUP BY ORDERS.OrderKey
                  ,WAVE.Wavekey
                  ,ORDERS.storerkey
                  ,PICKD.Loc
                  ,PICKD.sku
                  ,SKU.DESCR
                  ,ORDERS.BuyerPO
                  ,ORDERS.UserDefine09
                  ,ORDERS.C_City
                  ,ORDERS.C_Company
                  ,ISNULL(LOTT.Lottable02,'')
                  ,ISNULL(LOTT.Lottable03,'') 
                  ,CONVERT(NVARCHAR(10)
                  ,LOTT.Lottable04,111)
                  ,WAVE.AddDate              --WZ01
                  ,SKU.RETAILSKU             --WZ01
                  ,C01.UDF05                 --WZ01
                  ,ORDERS.LoadKey            --WZ01
         ORDER BY wave.wavekey, ORDERS.OrderKey 
 
   IF @c_PreGenRptData = 'Y'  
   BEGIN  
     
   
       SELECT @n_pickslips_required = COUNT(DISTINCT OrderKey)  
       FROM #TEMP_WAVPICKSUM002  
       WHERE ISNULL(RTRIM(Pickheaderkey),'') = ''   
  
       IF @@ERROR <> 0  
       BEGIN  
        GOTO FAILURE  
       END  
       ELSE IF @n_pickslips_required > 0  
       BEGIN  
        EXECUTE nspg_GetKey 'PICKSLIP', 9, @c_pickheaderkey OUTPUT, @b_success OUTPUT, @n_err  OUTPUT, @c_errmsg OUTPUT, 0, @n_pickslips_required  
  
        INSERT INTO PICKHEADER (PickHeaderKey, OrderKey, WaveKey, PickType, Zone, TrafficCop)  
        SELECT 'P' + RIGHT ( REPLICATE ('0', 9) +  
        dbo.fnc_LTrim( dbo.fnc_RTrim(  
        STR(CAST(@c_pickheaderkey AS INT) + (SELECT COUNT(DISTINCT OrderKey)  
                     FROM #TEMP_WAVPICKSUM002 AS Rank  
                     WHERE Rank.OrderKey < #TEMP_WAVPICKSUM002.OrderKey  
                     AND ISNULL(RTRIM(Rank.Pickheaderkey),'') = '' )   
          ) -- str  
          )) -- dbo.fnc_RTrim  
          , 9)  
         , OrderKey, WaveKey, '0', '8', ''  
        FROM #TEMP_WAVPICKSUM002  
        WHERE ISNULL(RTRIM(Pickheaderkey),'') = '' 
        GROUP By WaveKey, OrderKey  
  
        UPDATE #TEMP_WAVPICKSUM002  
        SET Pickheaderkey = PICKHEADER.PickHeaderKey  
        FROM PICKHEADER (NOLOCK)  
        WHERE PICKHEADER.WaveKey = #TEMP_WAVPICKSUM002.Wavekey  
        AND   PICKHEADER.OrderKey = #TEMP_WAVPICKSUM002.OrderKey  
        AND   PICKHEADER.Zone = '8'  
        AND   ISNULL(RTRIM(#TEMP_WAVPICKSUM002.Pickheaderkey),'') = '' 
       END  
  
       GOTO SUCCESS  
END
ELSE
BEGIN
  GOTO SUCCESS  
END
  
  
 FAILURE:  
 DELETE FROM #TEMP_WAVPICKSUM002  
 SUCCESS:  

 -- Do Auto Scan-in when Configkey is setup.  
 SET @c_StorerKey = ''  
 SET @c_PickSlipNo = ''  
  
   SELECT DISTINCT @c_StorerKey = StorerKey  
   FROM #TEMP_WAVPICKSUM002 (NOLOCK)  

    IF @c_PreGenRptData = 'Y'  
    BEGIN  
       IF EXISTS (SELECT 1 FROM STORERCONFIG (NOLOCK) WHERE CONFIGKEY = 'AUTOSCANIN'  
             AND SValue = '1' AND StorerKey = @c_StorerKey)  
       BEGIN  
        DECLARE C_AutoScanPickSlip CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
        SELECT DISTINCT Pickheaderkey  
          FROM #TEMP_WAVPICKSUM002 (NOLOCK)  
  
        OPEN C_AutoScanPickSlip  
        FETCH NEXT FROM C_AutoScanPickSlip INTO @c_PickSlipNo  
  
        WHILE @@FETCH_STATUS <> -1  
        BEGIN  
         IF NOT EXISTS (SELECT 1 FROM PICKINGINFO (NOLOCK) Where PickSlipNo = @c_PickSlipNo)  
         BEGIN  
          INSERT INTO PICKINGINFO (PickSlipNo, ScanInDate, PickerID, ScanOutDate)  
          VALUES (@c_PickSlipNo, GetDate(), sUser_sName(), NULL)  
  
          IF @@ERROR <> 0  
          BEGIN  
           SELECT @n_continue = 3  
           SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 61900  
           SELECT @c_errmsg = 'NSQL' + CONVERT(char(5),@n_err) +  
                  ': Insert PickingInfo Failed. (ISP_RPT_WV_WAVPICKSUM_002)' + ' ( ' +  
                  ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '  
          END  
         END -- PickSlipNo Does Not Exist  
  
         FETCH NEXT FROM C_AutoScanPickSlip INTO @c_PickSlipNo  
        END  
        CLOSE C_AutoScanPickSlip  
        DEALLOCATE C_AutoScanPickSlip  
       END -- Configkey is setup  

    END
   
    IF @c_PreGenRptData = ''  
    BEGIN
      
      SELECT  @c_CNT = COUNT(DISTINCT Orderkey) FROM #TEMP_WAVPICKSUM002 (NOLOCK)             --WZ01
          SELECT DISTINCT '' AS ordekey, tp.WaveKey AS wavekey, SUM(tp.Qty) AS qty,  '' AS Pickheaderkey,  
             tp.Storerkey, 
             tp.PLOC, tp.SKU, tp.SDESCR,  
             tp.LOTT02, tp.LOTT03,   
             tp.LOTT04
             ,tp.LoadKey, tp.AddDate, @c_CNT AS CountOrder, tp.RETAILSKU, tp.C01     --WZ01
          FROM #TEMP_WAVPICKSUM002 AS tp  
          group by tp.WaveKey,tp.Storerkey, 
             tp.PLOC, tp.SKU, tp.SDESCR,  
             tp.LOTT02, tp.LOTT03,   
             tp.LOTT04,
             tp.LoadKey, tp.AddDate, tp.RETAILSKU, tp.C01     --WZ01
    END                  


     IF OBJECT_ID('tempdb..#TEMP_WAVPICKSUM002') IS NOT NULL  
      DROP TABLE #TEMP_WAVPICKSUM002  
    
  
 END

SET QUOTED_IDENTIFIER OFF 

GO