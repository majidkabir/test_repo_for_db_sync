SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Stored Proc: isp_GetPickSlipWave18_New                               */  
/* Creation Date: 2020-03-31                                            */  
/* Copyright: LF Logistics                                              */  
/* Written by: Wan                                                      */  
/*                                                                      */  
/* Purpose: WMS-12723 - SG - PMI - Picking Slip [CR]                    */  
/*        :                                                             */  
/* Called By: Wave Print PickSlip = PLIST_WAVE                          */  
/*          :                                                           */  
/* PVCS Version: 1.0                                                    */  
/*                                                                      */  
/* Version: 7.0                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date        Author   Ver   Purposes                                  */ 
/* 05-Jun-2020 LZG      1.1   INC1161388 - Revise PickSlipNo generation */
/*                                         logic (ZG01)                 */ 
/* 16-Jun-2020 CSCHONG  1.1   WMS-13625 revised grouping (CS01)         */  
/* 05-Oct-2021 MINGLE   1.2   WMS-18083 add storerkey(ML01)             */
/* 15-FEB-2023 CSCHONG  1.3   WMS-21701 revised report logic (CS02)     */
/************************************************************************/  
CREATE   PROC [dbo].[isp_GetPickSlipWave18_New]  
         @c_Wavekey_Type          NVARCHAR(15)     
      ,  @c_InputType             NVARCHAR(5) = ''                 
AS  
BEGIN  
   SET NOCOUNT ON  
   SET ANSI_NULLS OFF  
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE @n_StartTCnt       INT = @@TRANCOUNT  
         , @n_Continue        INT = 1  
         , @b_Success         INT = 1      
         , @n_err             INT = 0                
         , @c_ErrMsg          NVARCHAR(255) = ''  
  
         , @n_Batch           INT = 0  
         , @n_Pickslipno      INT = 0  
         , @c_Wavekey         NVARCHAR(10)  = ''  
         , @c_Orderkey        NVARCHAR(10)  = ''  
         , @c_Pickslipno      NVARCHAR(10)  = ''  
         , @c_PickDetailKey   NVARCHAR(10)  = ''  
          
         , @CUR_PICK       CURSOR  
  
   WHILE @@TRANCOUNT > 0  
   BEGIN  
      COMMIT TRAN  
   END  
     
   SET @c_Wavekey = LEFT(@c_Wavekey_Type, 10)   
  
   IF @c_InputType = 'MAIN'    
   BEGIN    
      GOTO QUIT_SP    
   END    
  
   IF OBJECT_ID('tempdb..#TMP_HDR','u') IS NOT NULL  
   BEGIN  
      DROP TABLE #TMP_HDR;  
   END  
  
   CREATE TABLE #TMP_HDR  
      (  Wavekey           NVARCHAR(10)   NOT NULL DEFAULT('')           
      ,  Loadkey           NVARCHAR(10)   NOT NULL DEFAULT('')  
      ,  Orderkey          NVARCHAR(10)   NOT NULL DEFAULT('') PRIMARY KEY  
      ,  OrderType         NVARCHAR(10)   NOT NULL DEFAULT('')  
      ,  ExternOrderkey    NVARCHAR(30)   NOT NULL DEFAULT('')  
      ,  C_Company         NVARCHAR(45)   NOT NULL DEFAULT('')   
      ,  [Route]           NVARCHAR(10)   NOT NULL DEFAULT('')   
      ,  PickSlipNo        NVARCHAR(10)   NOT NULL DEFAULT('')  
      ,  Reprint           CHAR(1)        NOT NULL DEFAULT('N')  
      )  
  
   IF OBJECT_ID('tempdb..#TMP_DET','u') IS NOT NULL  
   BEGIN  
      DROP TABLE #TMP_DET;  
   END  
  
   CREATE TABLE #TMP_DET  
      (  RowID             INT            IDENTITY(1,1)  PRIMARY KEY  
      ,  Orderkey          NVARCHAR(10)   NOT NULL DEFAULT('')   
      ,  DropID            NVARCHAR(20)   NOT NULL DEFAULT('')  
      ,  CaseID            NVARCHAR(20)   NOT NULL DEFAULT('')  
      ,  CSZone            NVARCHAR(10)   NOT NULL DEFAULT('')  
      ,  PickZone          NVARCHAR(10)   NOT NULL DEFAULT('')  
      ,  Loc               NVARCHAR(10)   NOT NULL DEFAULT('')   
      ,  LogicalLocation   NVARCHAR(10)   NOT NULL DEFAULT('')  
      ,  Storerkey         NVARCHAR(15)   NOT NULL DEFAULT('')   
      ,  Sku               NVARCHAR(20)   NOT NULL DEFAULT('')   
      ,  SkuDescr          NVARCHAR(60)   NOT NULL DEFAULT('')  
      ,  Qty               INT            NOT NULL DEFAULT(0)  
      ,  BoxType           NVARCHAR(20)   NOT NULL DEFAULT('')  
      ,  CSQty             INT            NOT NULL DEFAULT(0)  
      ,  CTNQty            INT            NOT NULL DEFAULT(0)  
      ,  PACKQty           INT            NOT NULL DEFAULT(0)   
      ,  NoOfLinePerDropID INT            NOT NULL DEFAULT(0)   
      ,  CSQtyPerDropID    INT            NOT NULL DEFAULT(0)  
      ,  CTNQtyPerDropID   INT            NOT NULL DEFAULT(0)   
      ,  PackQtyPerDropID  INT            NOT NULL DEFAULT(0)   
      ,  CSQtyPerPSlip     INT            NOT NULL DEFAULT(0)  
      ,  CTNQtyPerPSlip    INT            NOT NULL DEFAULT(0)   
      ,  PackQtyPerPSlip   INT            NOT NULL DEFAULT(0)   
      ,  CaseCnt           FLOAT          NOT NULL DEFAULT(0.00)  
      ,  OtherUnit1        FLOAT          NOT NULL DEFAULT(0.00)  
      )  
  
   IF OBJECT_ID('tempdb..#TMP_Qty','u') IS NOT NULL  
   BEGIN  
      DROP TABLE #TMP_Qty;  
   END  
  
   CREATE TABLE #TMP_Qty  
      (  RowID             INT            IDENTITY(1,1)  PRIMARY KEY  
      ,  Orderkey          NVARCHAR(10)   NOT NULL DEFAULT('')  
      ,  DropID            NVARCHAR(10)   NOT NULL DEFAULT('')  
      ,  Loc               NVARCHAR(10)   NOT NULL DEFAULT('')   
      ,  Sku               NVARCHAR(20)   NOT NULL DEFAULT('')   
      ,  Qty               INT            NOT NULL DEFAULT(0)                
      ,  CSQty             INT            NOT NULL DEFAULT(0)  
      ,  CTNQty            INT            NOT NULL DEFAULT(0)  
      ,  PACKQTY           INT            NOT NULL DEFAULT(0)  
      )  
   INSERT INTO #TMP_HDR  
      (  Wavekey  
      ,  Loadkey  
      ,  Orderkey  
      ,  OrderType   
      ,  ExternOrderkey  
      ,  C_Company  
      ,  [Route]  
      ,  PickSlipNo  
      ,  Reprint  
      )  
  
   SELECT Wavekey = @c_Wavekey  
         ,OH.Loadkey  
         ,OH.Orderkey  
         ,OH.[Type]  
         ,ExternOrderkey = ISNULL(OH.ExternOrderkey,'')  
         ,ISNULL(OH.C_Company,'')  
         ,OH.[Route]  
         ,PickSlipNo = ISNULL(PH.PickHeaderKey,'')  
         ,Reprint    = CASE WHEN PH.PickHeaderKey IS NULL THEN 'N' ELSE 'Y' END   
   FROM WAVE       WH WITH (NOLOCK)   
   JOIN WAVEDETAIL WD WITH (NOLOCK) ON WH.Wavekey = WD.Wavekey  
   JOIN ORDERS     OH WITH (NOLOCK) ON WD.Orderkey= OH.Orderkey  
   LEFT JOIN PICKHEADER PH WITH (NOLOCK) ON WD.Wavekey = PH.Wavekey  
                                        AND OH.Orderkey= PH.Orderkey  
                                        AND PH.[Zone] = '3'  
   WHERE WH.Wavekey = @c_Wavekey  
  
   INSERT INTO #TMP_DET  
      (   Orderkey  
      ,   DropID  
      ,   CaseID  
      ,   CSZone  
      ,   PickZone  
      ,   Loc  
      ,   LogicalLocation  
      ,   Storerkey
      ,   Sku  
      ,   SkuDescr  
      ,   Qty  
      ,   CaseCnt  
      ,   OtherUnit1  
      ,   BoxType  
      )  
   SELECT PD.Orderkey  
         ,DropID   
         ,CaseID  
         ,CSZone = CASE WHEN L.Pickzone IN ('PMICASEPZ') THEN L.Pickzone ELSE '' END  
         ,L.PickZone  
         ,Loc = CASE WHEN L.Pickzone IN ('PMICARPZ','PMIPACKPZ')   
                     THEN SUBSTRING(LTRIM(RTRIM(UPPER(PD.Loc))),5,2) + '-' + SUBSTRING(LTRIM(RTRIM(UPPER(PD.Loc))),7,2)    
                     WHEN L.Pickzone IN ('PMICASEPZ') AND LEFT(LTRIM(RTRIM(UPPER(PD.Loc))),4) = 'EX2S'     
                     THEN SUBSTRING(LTRIM(RTRIM(UPPER(PD.Loc))),4,1) + '-' + SUBSTRING(LTRIM(RTRIM(UPPER(PD.Loc))),5,2)    
                     WHEN L.Pickzone IN ('PMIAGING')     
                     THEN SUBSTRING(LTRIM(RTRIM(UPPER(PD.Loc))),4,1) + '-' + SUBSTRING(LTRIM(RTRIM(UPPER(PD.Loc))),5,2) + '-' +     
                          SUBSTRING(LTRIM(RTRIM(UPPER(PD.Loc))),7,2)   
                     ELSE PD.Loc  
                     END  
         ,L.LogicalLocation
         ,PD.Storerkey     --ML01 
         ,PD.Sku  
         ,SkuDescr = ISNULL(RTRIM(S.Descr),'')  
         ,Qty      = PD.Qty  
         ,P.CaseCnt  
         ,P.OtherUnit1  
         ,BoxType = CASE PD.CartonType WHEN 'PM001' THEN 'SMALL'  
                                       WHEN 'PM002' THEN 'MEDIUM'  
                                       WHEN 'PM003' THEN 'LARGE'  
                                       WHEN 'PM004' THEN 'FULL CASE'  
                                       ELSE ''  
                                       END   
   FROM #TMP_HDR   OH  
   JOIN PICKDETAIL PD WITH (NOLOCK) ON OH.Orderkey = PD.Orderkey  
   JOIN LOC        L  WITH (NOLOCK) ON PD.Loc = L.Loc  
   JOIN SKU        S  WITH (NOLOCK) ON PD.Storerkey = S.StorerKey AND PD.Sku = S.Sku  
   JOIN PACK       P  WITH (NOLOCK) ON S.Packkey = P.Packkey  
   WHERE PD.[Status] < '5'  
   ORDER BY OH.PickSlipNo  
         ,  PD.DropID  
         ,  L.PickZone  
         ,  L.LogicalLocation  
         ,  L.Loc  
         ,  PD.Sku  
  
   IF EXISTS ( SELECT 1  
               FROM #TMP_DET  
               WHERE DropID = ''  
               OR CaseID = ''  
               )  
   BEGIN  
      SET @n_Continue = 3  
      SET @c_ErrMsg = 'Either DropID OR CaseID is blank'  
      GOTO QUIT_SP  
   END  
  
   INSERT INTO #TMP_QTY  
      (  Orderkey  
      ,  DropID  
      ,  Loc  
      ,  Sku  
      ,  Qty  
      ,  CSQty  
      ,  CTNQty  
      ,  PACKQTY  
      )  
   SELECT D.Orderkey  
      , D.DropID  
      , D.Loc  
      , D.sku  
      , Qty     = SUM(D.Qty)  
      , CSQty   = CASE WHEN D.CaseCnt    = 0 THEN 0 ELSE FLOOR(SUM(D.Qty) / D.CaseCnt) END  
      , CTNQty  = CASE WHEN D.OtherUnit1 = 0 THEN 0   
                       WHEN D.CaseCnt    = 0 THEN FLOOR(SUM(D.Qty) / D.OtherUnit1)   
                       WHEN SUM(D.Qty) % CONVERT(INT, D.CaseCnt) >= D.OtherUnit1 THEN FLOOR((SUM(D.Qty) % CONVERT(INT, D.CaseCnt)) / D.OtherUnit1)  
                       ELSE 0  
                       END  
      , PACKQty = CASE WHEN D.CaseCnt = 0 AND D.OtherUnit1 = 0 THEN SUM(D.Qty)   
                       WHEN D.OtherUnit1 = 0 THEN SUM(D.Qty) % CONVERT(INT, D.CaseCnt)   
                       ELSE SUM(D.Qty) % CONVERT(INT, D.OtherUnit1)   
                       END  
   FROM #TMP_DET D  
   GROUP BY D.Orderkey  
         ,  D.DropID  
         ,  D.Loc  
         ,  D.Sku  
         ,  D.CaseCnt  
         ,  D.OtherUnit1  
  
   UPDATE #TMP_DET  
   SET CSQty   = Q.CSQty  
      ,CTNQty  = Q.CTNQty  
      ,PACKQty = Q.PACKQty  
   FROM #TMP_DET D  
   JOIN #TMP_QTY Q ON D.Orderkey = Q.Orderkey AND D.DropID = Q.DropID AND D.Loc = Q.Loc  
                  AND D.Sku = Q.Sku  
  
   ;WITH DROPID_SUM AS  
   ( SELECT Q.Orderkey  
         ,  Q.DropID  
         ,  NoOfLinePerDropID = COUNT(1)  
         ,  CSQtyPerDropID   = SUM(CSQty)  
         ,  CTNQtyPerDropID  = SUM(CTNQty)  
         ,  PACKQtyPerDropID = SUM(PACKQty)  
      FROM #TMP_QTY Q   
      GROUP BY Q.Orderkey  
            ,  Q.DropID  
   )  
  
   UPDATE #TMP_DET  
   SET NoOfLinePerDropID= S.NoOfLinePerDropID  
      ,CSQtyPerDropID   = S.CSQtyPerDropID  
      ,CTNQtyPerDropID  = S.CTNQtyPerDropID  
      ,PACKQtyPerDropID = S.PACKQtyPerDropID  
   FROM #TMP_DET D  
   JOIN DROPID_SUM S ON D.Orderkey = S.Orderkey AND D.DropID = S.DropID  
  
  ;WITH ORDER_SUM AS  
   ( SELECT Q.Orderkey  
         ,  CSQtyPerPSlip   = SUM(CSQty)  
         ,  CTNQtyPerPSlip  = SUM(CTNQty)  
         ,  PACKQtyPerPSlip = SUM(PACKQty)  
      FROM #TMP_QTY Q   
      GROUP BY Q.Orderkey  
    )  
  
   UPDATE #TMP_DET  
   SET CSQtyPerPSlip  = S.CSQtyPerPSlip  
      ,CTNQtyPerPSlip = S.CTNQtyPerPSlip  
      ,PACKQtyPerPSlip= S.PACKQtyPerPSlip  
   FROM #TMP_DET D  
   JOIN ORDER_SUM S ON D.Orderkey = S.Orderkey  
  
   /*SET @n_Batch = 0                       -- ZG01
   SELECT @n_Batch = COUNT(1)  
   FROM #TMP_HDR H  
   WHERE H.PickSlipNo = ''  
  
   IF @n_Batch > 0  
   BEGIN  
      EXECUTE nspg_GetKey           
            @keyname   = 'PICKSLIP'        
         ,  @fieldlength= 9        
         ,  @keystring = @c_Pickslipno OUTPUT        
         ,  @b_Success = @b_Success    OUTPUT        
 ,  @n_err     = @n_err        OUTPUT        
         ,  @c_errmsg  = @c_errmsg     OUTPUT   
         ,  @n_batch   = @n_Batch                 
                                 
      SET @n_Pickslipno = CONVERT(INT, @c_Pickslipno)    
  
      UPDATE H  
         SET PickSlipNo = P.PickSlipNo  
      FROM #TMP_HDR H  
      JOIN ( SELECT T.Orderkey  
                  , PickSlipNo = 'P' + RIGHT('000000000' + CONVERT(NVARCHAR(9), ROW_NUMBER() OVER (ORDER BY T.Orderkey) + @n_Pickslipno),9)  
             FROM #TMP_HDR T  
             WHERE T.PickSlipNo = ''  
             AND   T.Reprint = 'N'  
            ) P ON P.Orderkey = H.Orderkey   
  
      INSERT INTO PICKHEADER   
         (  PickHeaderKey  
         ,  Wavekey  
         ,  Orderkey  
         ,  PickType  
         ,  [Zone]  
         ,  ExternOrderKey  
         ,  LoadKey  
         ,  ConsoOrderKey  
         )  
      SELECT H.Pickslipno  
         ,  H.Wavekey  
         ,  H.Orderkey  
         ,  '0'  
         ,  '3'  
         ,  ''  
         ,  ''  
         ,  ''  
      FROM #TMP_HDR H  
      WHERE H.Reprint = 'N'  
      ORDER BY H.Orderkey  
  
      IF @@ERROR <> 0   
      BEGIN  
         SET @n_Continue = 3  
         SET @n_Err = 67100  
         SET @c_ErrMsg = 'NSQL'+ CONVERT(NVARCHAR(5), @n_Err) + ': Error Insert Into PICKHEADER table.(isp_GetPickSlipWave18_New)'  
         GOTO QUIT_SP  
      END  
   END*/                        -- ZG01
  
   -- ZG01 (Start)
   DECLARE CUR_HDR CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
   SELECT DISTINCT OrderKey 
   FROM #TMP_HDR H  
   WHERE H.PickSlipNo = ''  
   
   OPEN CUR_HDR    
   FETCH NEXT FROM CUR_HDR INTO @c_Orderkey   
    
   WHILE @@FETCH_STATUS <> -1   
   BEGIN    
      SET @c_Pickslipno = ''
      EXECUTE nspg_GetKey           
            @keyname   = 'PICKSLIP'        
         ,  @fieldlength= 9        
         ,  @keystring = @n_Pickslipno OUTPUT        
         ,  @b_Success = @b_Success    OUTPUT        
         ,  @n_err     = @n_err        OUTPUT        
         ,  @c_errmsg  = @c_errmsg     OUTPUT   
                                 
      SET @c_Pickslipno = 'P' + RIGHT('000000000' + CONVERT(NVARCHAR(9), @n_Pickslipno),9) 
    
      UPDATE H  
         SET PickSlipNo = @c_Pickslipno
      FROM #TMP_HDR H  
      WHERE H.OrderKey = @c_Orderkey

      INSERT INTO PICKHEADER   
         (  PickHeaderKey  
         ,  Wavekey  
         ,  Orderkey  
         ,  PickType  
         ,  [Zone]  
         ,  ExternOrderKey  
         ,  LoadKey  
         ,  ConsoOrderKey  
         )  
      SELECT H.Pickslipno  
         ,  H.Wavekey  
         ,  H.Orderkey  
         ,  '0'  
         ,  '3'  
         ,  ''  
         ,  ''  
         ,  ''  
      FROM #TMP_HDR H  
      WHERE H.Reprint = 'N'  
      AND H.OrderKey = @c_Orderkey
  
      IF @@ERROR <> 0   
      BEGIN  
         SET @n_Continue = 3  
         SET @n_Err = 67100  
         SET @c_ErrMsg = 'NSQL'+ CONVERT(NVARCHAR(5), @n_Err) + ': Error Insert Into PICKHEADER table.(isp_GetPickSlipWave18_New)'  
         GOTO QUIT_SP  
      END  
      
   FETCH NEXT FROM CUR_HDR INTO @c_Orderkey 
   END    
   CLOSE CUR_HDR    
   DEALLOCATE CUR_HDR   
   -- ZG01 (End)
  
   SET @CUR_PICK = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
   SELECT PD.PickDetailKey  
         ,H.PickSlipNo  
   FROM #TMP_HDR H WITH (NOLOCK)  
   JOIN PICKDETAIL PD WITH (NOLOCK) ON H.Orderkey = PD.Orderkey  
   WHERE ( H.PickSlipNo <> PD.PickSlipNo OR PD.PickSlipNo IS NULL OR PD.PickSlipNo = '' )  
  
   OPEN @CUR_PICK  
     
   FETCH NEXT FROM @CUR_PICK INTO @c_PickDetailKey, @c_PickSlipNo   
   WHILE @@FETCH_STATUS <> -1  
   BEGIN  
      UPDATE PICKDETAIL  
         SET PickSlipNo = @c_Pickslipno  
            ,TrafficCop = NULL  
            ,EditWho  = SUSER_SNAME()  
            ,EditDate = GETDATE()  
      WHERE PickDetailKey = @c_PickDetailKey  
          
      IF @@ERROR <> 0   
      BEGIN  
         SET @n_Continue = 3  
         SET @n_Err = 67100  
         SET @c_ErrMsg = 'NSQL'+ CONVERT(NVARCHAR(5), @n_Err) + ': Error Insert Into PICKHEADER table.(isp_GetPickSlipWave18_New)'  
         GOTO QUIT_SP  
      END  
  
      FETCH NEXT FROM @CUR_PICK INTO @c_PickDetailKey, @c_PickSlipNo   
   END  
   CLOSE @CUR_PICK  
   DEALLOCATE @CUR_PICK  
  
   QUIT_SP:  
   WHILE @@TRANCOUNT < @n_StartTCnt  
   BEGIN   
      BEGIN TRAN  
   END  
  
   IF @c_InputType = 'MAIN'    
   BEGIN  
       --CS02 S
     DECLARE @c_rtnerrmsg    NVARCHAR(100) = '',
             @c_GetOrderkey  NVARCHAR(20)   = ''

     SELECT TOP 1 @c_GetOrderkey = OH.OrderKey
     FROM  WAVE       WH WITH (NOLOCK)
     JOIN WAVEDETAIL WD WITH (NOLOCK) ON WH.Wavekey = WD.Wavekey
     JOIN ORDERS     OH WITH (NOLOCK) ON WD.Orderkey= OH.Orderkey
     LEFT JOIN PICKHEADER PH WITH (NOLOCK) ON WD.Wavekey = PH.Wavekey
                                                       AND OH.Orderkey= PH.Orderkey
                                                       AND PH.[Zone] = '3'
     WHERE WH.Wavekey = @c_Wavekey 
     AND ISNULL(OH.userdefine07,'') = '' 
     AND OH.TYPE in ('CCB2B') AND oh.priority <> 'TOPGT' 
      
      IF ISNULL(@c_GetOrderkey,'') <> ''
      BEGIN
          SET @c_rtnerrmsg = @c_GetOrderkey + ' not yet assigned route value'
      END
      ELSE
      BEGIN
       SET @c_rtnerrmsg = ''    
      END

      --CS02 E

      SELECT Wavekey = @c_Wavekey,rtnerrmsg = @c_rtnerrmsg --CS02   
      RETURN   
   END  
  
   IF @n_Continue = 3  
   BEGIN  
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012  
      RETURN  
   END  
  
/*****************************************************/  
   CREATE TABLE #TMP_RESULT  
      (  
      --   RptSort           INT            NOT NULL DEFAULT('')  
      --,  PageGroup         INT            NOT NULL DEFAULT('')  
         First_Loc         NVARCHAR(10)   NOT NULL DEFAULT('')   
      ,  Wavekey           NVARCHAR(10)   NOT NULL DEFAULT('')           
      ,  Loadkey           NVARCHAR(10)   NOT NULL DEFAULT('')  
      ,  Orderkey          NVARCHAR(10)   NOT NULL DEFAULT('')  
      ,  OrderType         NVARCHAR(10)   NOT NULL DEFAULT('')  
      ,  ExternOrderkey    NVARCHAR(30)   NOT NULL DEFAULT('')  
      ,  C_Company         NVARCHAR(45)   NOT NULL DEFAULT('')   
      ,  [Route]           NVARCHAR(10)   NOT NULL DEFAULT('')   
      ,  PickSlipNo        NVARCHAR(10)   NOT NULL DEFAULT('')  
      ,  Reprint           CHAR(1)        NOT NULL DEFAULT('N')  
      ,  DropID            NVARCHAR(20)   NOT NULL DEFAULT('')  
      ,  PickZone          NVARCHAR(10)   NOT NULL DEFAULT('')  
      ,  Loc               NVARCHAR(10)   NOT NULL DEFAULT('')   
      ,  Storerkey         NVARCHAR(15)   NOT NULL DEFAULT('')   
      ,  Sku               NVARCHAR(20)   NOT NULL DEFAULT('')   
      ,  SkuDescr          NVARCHAR(60)   NOT NULL DEFAULT('')  
      ,  BoxType           NVARCHAR(20)   NOT NULL DEFAULT('')  
      ,  CSQty             INT            NOT NULL DEFAULT(0)  
      ,  CTNQty            INT            NOT NULL DEFAULT(0)  
      ,  PACKQty           INT            NOT NULL DEFAULT(0)   
      ,  NoOfLinePerDropID INT            NOT NULL DEFAULT(0)   
      ,  CSQtyPerDropID    INT            NOT NULL DEFAULT(0)  
      ,  CTNQtyPerDropID   INT            NOT NULL DEFAULT(0)   
      ,  PackQtyPerDropID  INT            NOT NULL DEFAULT(0)   
      ,  CSQtyPerPSlip     INT            NOT NULL DEFAULT(0)  
      ,  CTNQtyPerPSlip    INT            NOT NULL DEFAULT(0)   
      ,  PackQtyPerPSlip   INT            NOT NULL DEFAULT(0)   
      ,  CSZone            NVARCHAR(10)   NOT NULL DEFAULT('')  
      ,  LogicalLocation   NVARCHAR(10)   NOT NULL DEFAULT('')  
      )  
  
   INSERT INTO #TMP_RESULT  
      SELECT   
     --    RptSort   = ROW_NUMBER() OVER ( ORDER BY D.CSZone DESC, H.PickSlipNo, D.DropID, D.LogicalLocation )                        --CS01
     -- ,  PageGroup = CASE WHEN D.PickZone <> 'PMICASEPZ' THEN DENSE_RANK() OVER ( ORDER BY D.CSZone DESC, H.PickSlipNo, D.DropID )   
     --                   ELSE DENSE_RANK() OVER ( ORDER BY D.CSZone DESC, H.PickSlipNo) END   --CS01  
 
     First_Loc = (Select Top 1 Loc   
     From #TMP_HDR HD1, #TMP_DET DT1  
     WHERE HD1.Orderkey = H.Orderkey  
     AND DT1.Orderkey = HD1.Orderkey  
     AND DT1.CSZone = D.CSZone  
     AND DT1.DropID = D.DropID  
     AND HD1.PickSlipNo = H.PickSlipNo  
     ORDER BY DT1.Loc)  
      ,  H.Wavekey  
      ,  H.Loadkey  
      ,  H.Orderkey  
      ,  H.OrderType   
      ,  H.ExternOrderkey  
      ,  H.C_Company  
      ,  H.[Route]  
      ,  H.PickSlipNo  
      ,  H.Reprint  
      ,  D.DropID  
      ,  D.PickZone  
      ,  D.Loc  
      ,  D.Storerkey  
      ,  D.Sku  
      ,  D.SkuDescr  
      ,  D.BoxType  
      ,  D.CSQty   
      ,  D.CTNQty  
      ,  D.PACKQty  
      ,  D.NoOfLinePerDropID  
      ,  D.CSQtyPerDropID  
      ,  D.CTNQtyPerDropID  
      ,  D.PACKQtyPerDropID  
      ,  D.CSQtyPerPSlip  
      ,  D.CTNQtyPerPSlip  
      ,  D.PACKQtyPerPSlip  
      ,  D.CSZone  
      ,  D.LogicalLocation  
   FROM #TMP_HDR H  
   JOIN #TMP_DET D ON H.Orderkey = D.Orderkey  
   GROUP BY   
         H.Wavekey  
      ,  H.Loadkey  
      ,  H.Orderkey  
      ,  H.OrderType   
      ,  H.ExternOrderkey  
      ,  H.C_Company  
      ,  H.[Route]  
      ,  H.PickSlipNo  
      ,  H.Reprint  
      ,  D.DropID  
      ,  D.CSZone  
      ,  D.PickZone  
      ,  D.Loc  
      ,  D.Logicallocation  
      ,  D.Storerkey  
      ,  D.Sku  
      ,  D.SkuDescr  
      ,  D.BoxType  
      ,  D.CSQty   
      ,  D.CTNQty  
      ,  D.PACKQty  
      ,  D.NoOfLinePerDropID  
      ,  D.CSQtyPerDropID  
      ,  D.CTNQtyPerDropID  
      ,  D.PACKQtyPerDropID  
      ,  D.CSQtyPerPSlip  
      ,  D.CTNQtyPerPSlip  
      ,  D.PACKQtyPerPSlip  
   ORDER BY D.CSZone DESC  
         ,  H.PickSlipNo  
         ,  D.DropID  
         ,  D.LogicalLocation  
  
  --CS01
   SELECT   
      --   RptSort  
      --,  PageGroup  
           RptSort   = ROW_NUMBER() OVER ( ORDER BY CSZone DESC, PickSlipNo, DropID, LogicalLocation )  
        ,  PageGroup = CASE WHEN PickZone <> 'PMICASEPZ' THEN DENSE_RANK() OVER ( ORDER BY CSZone DESC, First_Loc, DropID )   
                       ELSE DENSE_RANK() OVER ( ORDER BY CSZone DESC, PickSlipNo) END   --CS01  
      ,  First_Loc  
      ,  Wavekey  
      ,  Loadkey  
      ,  Orderkey  
      ,  OrderType   
      ,  ExternOrderkey  
      ,  C_Company  
      ,  [Route]  
      ,  PickSlipNo  
      ,  Reprint  
      ,  DropID  
      ,  PickZone  
      ,  Loc  
      ,  Storerkey  
      ,  Sku  
      ,  SkuDescr  
      ,  BoxType  
      ,  CSQty   
      ,  CTNQty  
      ,  PACKQty  
      ,  NoOfLinePerDropID  
      ,  CSQtyPerDropID  
      ,  CTNQtyPerDropID  
      ,  PACKQtyPerDropID  
      ,  CSQtyPerPSlip  
      ,  CTNQtyPerPSlip  
      ,  PACKQtyPerPSlip  
      ,  CSZone  
   FROM #TMP_RESULT  
   ORDER BY CSZone DESC  
         ,  PageGroup  
         ,  RptSort 
         ,  First_Loc  
   
END -- procedure


GO