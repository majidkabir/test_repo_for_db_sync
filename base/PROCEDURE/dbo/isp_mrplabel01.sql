SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

  
/************************************************************************/  
/* Stored Proc: isp_MRPLabel01                                          */  
/* Creation Date: 20-APR-2017                                           */  
/* Copyright: LF Logistics                                              */  
/* Written by: Wan                                                      */  
/*                                                                      */  
/* Purpose: WMS-1624 - SG Logitech MRP Label                            */  
/*        :                                                             */  
/* Called By: r_dw_carton_MRP_Label01_1                                 */  
/*          : r_dw_carton_MRP_Label01_2                                 */  
/*          : r_dw_carton_MRP_Label01_3                                 */  
/*                                                                      */  
/* PVCS Version: 2.0                                                    */  
/*                                                                      */  
/* Version: 7.0                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date        Author   Ver   Purposes                                  */  
/* 04-JUL-2017 Wan01    1.1   WMS-2332 - Changes to Logitech Packing    */  
/* 04-JUL-2017 Wan02    1.2   WMS-5011 - [CR] - SG Logitech - MRP Label */  
/* 17-JUN-2018 JimmyTan 1.3   WMS-5437 - [CR] - SG Logitech - MRP Label */  
/* 23-Aug-2019 CSCHONG  1.2   WMS-10266 revised field logic (CS01)      */  
/* 12-Aug-2020 WLChooi  1.5   WMS-14716 - Modify Logic (WL01)           */  
/* 13-Apr-2021 Mingle   1.6   WMS-16811 - Modify logic (ML01)           */  
/* 11-May-2022 WLChooi  1.6   DevOps Combine Script                     */  
/* 11-May-2022 WLChooi  1.7   WMS-19617 - Modify Logic (WL02)           */  
/* 07-Jul-2022 WLChooi  1.8   Bug Fix - Get Correct Month (WL03)        */  
/* 13-Jul-2022 Calvin   1.9   JSM-83301 KarSiong's CR (CLVN01)          */  
/* 26-Sep-2022 WLChooi  2.0   Bug Fix - Exclude CANC status SN (WL04)   */  
/************************************************************************/  
CREATE    PROC [dbo].[isp_MRPLabel01]  
           @c_PickSlipNo         NVARCHAR(10)  
         , @c_CartonNoStart      NVARCHAR(10)  
         , @c_CartonNoEnd        NVARCHAR(10)   
         , @c_SourceDW           NVARCHAR(50)   
  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET ANSI_NULLS OFF  
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE    
           @n_StartTCnt          INT  
         , @n_Continue           INT   
  
         , @n_MaxSurfaceFr       FLOAT   
         , @n_MaxSurfaceTo       FLOAT   
  
         , @c_LGTCC_Company      NVARCHAR(45)    
         , @c_LGTCC_Address1     NVARCHAR(45)    
         , @c_LGTCC_Address2     NVARCHAR(45)    
         , @c_LGTCC_Address3     NVARCHAR(45)    
         , @c_LGTCC_Address4     NVARCHAR(45)    
         , @c_LGTCC_City         NVARCHAR(45)    
         , @c_LGTCC_State        NVARCHAR(45)    
         , @c_LGTCC_Zip          NVARCHAR(18)    
         , @c_LGTCC_Country      NVARCHAR(30)    
         , @c_LGTCC_Contact1     NVARCHAR(30)    
         , @c_LGTCC_Phone1       NVARCHAR(18)    
         , @c_LGTCC_Email1       NVARCHAR(60)    
         , @c_LGTCC_Notes1       NVARCHAR(400)  
  
         , @c_LGTIM_Addr         NVARCHAR(400)  
         , @c_LGTRGST_Addr       NVARCHAR(400)  
  
         , @b_NextMonth          INT  
         , @dt_PrintDate         DATETIME  
         , @c_Orderkey           NVARCHAR(10)  
         , @c_OrderGroup         NVARCHAR(10)  
         , @c_Vessel             NVARCHAR(3)  
         , @c_VesselDate         DATETIME  
  
         , @n_RowRef             INT  
         , @n_NoOfCopy           INT  
  
         , @c_ColValue           NVARCHAR(4000)   --WL02  
         , @c_ColValue_New       NVARCHAR(4000)   --WL02  
         , @c_SI_ExtFld22        NVARCHAR(4000)   --WL02  
         , @c_SI_ExtFld22_New    NVARCHAR(4000)   --WL02  
  
   SET @n_StartTCnt = @@TRANCOUNT  
   SET @c_LGTCC_Company  = ''  
   SET @c_LGTCC_Address1 = ''  
   SET @c_LGTCC_Address2 = ''  
   SET @c_LGTCC_Address3 = ''  
   SET @c_LGTCC_Address4 = ''  
   SET @c_LGTCC_City     = ''  
   SET @c_LGTCC_State    = ''  
   SET @c_LGTCC_Zip      = ''  
   SET @c_LGTCC_Country  = ''  
   SET @c_LGTCC_Contact1 = ''  
   SET @c_LGTCC_Phone1   = ''  
   SET @c_LGTCC_Email1   = ''  
   SET @c_LGTCC_Notes1   = ''  
  
   WHILE @@TRANCOUNT > 0   
   BEGIN  
      COMMIT TRAN  
   END  
  
   IF OBJECT_ID('tempdb..#TMP_PACKSKU','U') IS NOT NULL  
   DROP TABLE #TMP_PACKSKU;  
  
   CREATE TABLE #TMP_PACKSKU   
      (  RowRef         INT   IDENTITY(1,1) PRIMARY KEY  
      ,  Orderkey       NVARCHAR(10)    
      ,  PickSlipNo     NVARCHAR(10)     
      ,  CartonNo       INT    
      ,  Storerkey      NVARCHAR(15)  
      ,  Sku            NVARCHAR(10)  
      ,  MaxSurface     FLOAT  
      ,  Qty            INT  
      ,  COO            NVARCHAR(150)  
      ,  SI_ExtFld03    MONEY           NULL  DEFAULT(0.00)  
      ,  SI_ExtFld21    NVARCHAR(4000)  NULL  DEFAULT('')  
      ,  SI_ExtFld22    NVARCHAR(4000)  NULL  DEFAULT('')  
      ,  ManufactureDT  NVARCHAR(50)    NULL   --WL02  
      )  
  
   IF OBJECT_ID('tempdb..#TMP_PRNCOPY','U') IS NOT NULL  
      DROP TABLE #TMP_PRNCOPY;  
  
   CREATE TABLE #TMP_PRNCOPY  
      (  RowRef         INT             NOT NULL DEFAULT('')  
      )  
  
   IF @c_SourceDW = 'r_dw_carton_mrp_label01_1'  
   BEGIN  
      SET @n_MaxSurfaceFr = 0.00  
      SET @n_MaxSurfaceTo = 500.00  
   END  
  
   IF @c_SourceDW = 'r_dw_carton_mrp_label01_2'  
   BEGIN  
      SET @n_MaxSurfaceFr = 500.01  
      SET @n_MaxSurfaceTo = 2500.00  
   END  
  
   IF @c_SourceDW = 'r_dw_carton_mrp_label01_3'  
   BEGIN  
      SET @n_MaxSurfaceFr = 2500.01  
      SET @n_MaxSurfaceTo = 9999999.99  
   END  
  
   INSERT INTO #TMP_PACKSKU  
      (  Orderkey  
      ,  PickSlipNo  
      ,  CartonNo  
      ,  Storerkey  
      ,  Sku  
      ,  MaxSurface  
      ,  Qty  
      ,  COO  
      ,  ManufactureDT   --WL02  
      )  
   SELECT DISTINCT     
         PACKHEADER.Orderkey  
      ,  PACKHEADER.PickSlipNo      
      ,  PACKDETAIL.CartonNo                
      ,  PACKDETAIL.Storerkey  
      ,  PACKDETAIL.Sku  
      ,  MaxSurface = CASE WHEN (PACK.WidthUOM3 * PACK.LengthUOM3) > (PACK.WidthUOM3 * PACK.HeightUOM3)   
                           AND  (PACK.WidthUOM3 * PACK.LengthUOM3) > (PACK.LengthUOM3* PACK.HeightUOM3)  
                           THEN (PACK.WidthUOM3 * PACK.LengthUOM3)  
                           WHEN (PACK.WidthUOM3 * PACK.HeightUOM3) > (PACK.LengthUOM3* PACK.HeightUOM3)  
                           AND  (PACK.WidthUOM3 * PACK.HeightUOM3) > (PACK.WidthUOM3 * PACK.LengthUOM3)  
                           THEN (PACK.WidthUOM3 * PACK.HeightUOM3)  
                           ELSE (PACK.LengthUOM3* PACK.HeightUOM3)  
                           END  
      ,  Qty = SUM(PACKDETAIL.Qty)  
      ,  COO = IsNull((Select MAX(CL.Description)  
                       From dbo.PickDetail PD with (nolock)   
                       INNER Join dbo.LotAttribute LA with (nolock)   
                             ON LA.StorerKey = PD.StorerKey and LA.SKU = PD.SKU and LA.Lot = PD.Lot  
                       INNER Join dbo.CodeLkUp CL with (nolock) on CL.Code = LA.Lottable11 AND CL.Storerkey = PD.Storerkey   --(CS01)  
                       Where PD.StorerKey = PACKDETAIL.Storerkey  
                       And PD.OrderKey = PACKHEADER.Orderkey  
                       And PD.SKU = PACKDETAIL.Sku           
                       And CL.ListName = 'LOGICTRY'), '') --WMS-5437   
      --WL02 S     
      --Example:  
      --LEFT(TRIM(SN.SerialNo),4) = 2208  
      --SUBSTRING(LEFT(TRIM(SN.SerialNo),4),1,2) = 22 -> 2022  
      --Get the month of Week 8 of 2022 -> February  
      --Formula below will get the first Monday of year, which is 2022-01-03 then add 8 weeks, then get the month  
      --Bug Fix - the no of week should minus one   --WL03  
      ,  ManufactureDT = CASE WHEN SKU.BUSR7 = 'YES' AND ISNULL(SN.SerialNo,'') <> ''  
                                 THEN CAST(DATENAME(MONTH, DATEADD(WEEK, CAST(SUBSTRING(LEFT(TRIM(SN.SerialNo),4),3,2) AS INT) - 1,   --WL03   
                                           DATEADD(DAY, (@@DATEFIRST - DATEPART(WEEKDAY, DATEADD(YEAR, SUBSTRING(CAST(DATEPART(year,GETDATE()) AS NVARCHAR),1,2)  
                                          + SUBSTRING(LEFT(TRIM(SN.SerialNo),4),1,2) - 1900, 0))  
                                          + (8 - @@DATEFIRST) * 2) % 7, DATEADD(YEAR, SUBSTRING(CAST(DATEPART(year,GETDATE()) AS NVARCHAR),1,2)   
                                          + SUBSTRING(LEFT(TRIM(SN.SerialNo),4),1,2) - 1900, 0)))) AS NVARCHAR) + ' '  
                                       + SUBSTRING(CAST(DATEPART(year,GETDATE()) AS NVARCHAR),1,2) + SUBSTRING(LEFT(TRIM(SN.SerialNo),4),1,2)  
                              WHEN ISNULL(SKU.BUSR7,'') IN ('','NO')  
                                 THEN CASE WHEN ISNULL(MAX(LAT.Lottable05),'19000101') = '19000101'  
                                           THEN ''  
                                           ELSE CAST(DATENAME(MONTH, DATEADD(MONTH, -2, MAX(LAT.Lottable05))) + ' ' +  
                                                DATENAME(YEAR, DATEADD(MONTH, -2, MAX(LAT.Lottable05))) AS NVARCHAR)  
                                           END  
                              END  
      --WL02 E  
   FROM PACKHEADER   WITH (NOLOCK)  
   JOIN PACKDETAIL   WITH (NOLOCK) ON (PACKHEADER.PickSlipNo = PACKDETAIL.PickSlipNo)  
   JOIN SKU          WITH (NOLOCK) ON (PACKDETAIL.Storerkey = SKU.Storerkey)  
                                   AND(PACKDETAIL.Sku = SKU.Sku)  
   JOIN PACK         WITH (NOLOCK) ON (SKU.Packkey = PACK.Packkey)  
   JOIN ORDERS       WITH (NOLOCK) ON (PACKHEADER.Orderkey = ORDERS.Orderkey)  
   LEFT JOIN STORER ST WITH (NOLOCK) ON ST.Storerkey = ORDERS.Consigneekey AND ST.consigneefor = 'LOGITECH'     --CS01  
   LEFT JOIN SERIALNO SN  WITH (NOLOCK) ON (SN.PickSlipNo = PACKDETAIL.PickSlipNo   --WL02  
                                        AND SN.CartonNo = PACKDETAIL.CartonNo       --WL02  
                                        AND SN.LabelLine = PACKDETAIL.LabelLine     --WL02  
                                        AND SN.ExternStatus NOT IN ('CANC') )       --WL04  
   CROSS APPLY (SELECT TOP 1 LA.Lottable05                                                --WL02  
                FROM PickDetail PD WITH (NOLOCK)                                          --WL02  
                INNER JOIN LotAttribute LA WITH (NOLOCK) ON LA.StorerKey = PD.StorerKey   --WL02  
                                                        AND LA.SKU = PD.SKU               --WL02  
                                                        AND LA.Lot = PD.Lot               --WL02  
                WHERE PD.StorerKey = PACKDETAIL.Storerkey                                 --WL02  
                And PD.OrderKey = PACKHEADER.Orderkey                                     --WL02  
                And PD.SKU = PACKDETAIL.Sku) AS LAT                                       --WL02  
   WHERE PACKDETAIL.PickSlipNo = @c_PickSlipNo  
   AND   PACKDETAIL.CartonNo >= CONVERT(INT, @c_CartonNoStart)   
   AND   PACKDETAIL.CartonNo <= CONVERT(INT, @c_CartonNoEnd)  
   --AND   ORDERS.C_Country = 'IN'                                                     --CS01  
   AND   ST.Notes2 = 'MRP'                                                             --CS01   
   AND   ORDERS.UserDefine10 NOT IN ('NO')                                             --(Wan01)  
   GROUP BY PACKHEADER.Orderkey  
         ,  PACKHEADER.PickSlipNo      
         ,  PACKDETAIL.CartonNo                
         ,  PACKDETAIL.Storerkey  
         ,  PACKDETAIL.Sku   
         ,  PACK.WidthUOM3   
         ,  PACK.LengthUOM3  
         ,  PACK.HeightUOM3  
         ,  SKU.BUSR7     --WL02  
         ,  SN.SerialNo   --WL02  
     
  
   IF (  SELECT COUNT(1) FROM #TMP_PACKSKU   
         WHERE PickSlipNo = @c_PickSlipNo  
         AND   MaxSurface Between @n_MaxSurfaceFr AND @n_MaxSurfaceTo  
      ) = 0  
   BEGIN  
      GOTO QUIT_SP  
   END  
  -- select * from #TMP_PACKSKU  
  
   UPDATE TMP  
   SET   SI_ExtFld03 = CASE WHEN ISNUMERIC(SI.ExtendedField03) = 1   
                            THEN CONVERT( MONEY, ISNULL(RTRIM(SI.ExtendedField03),'') )  
                            ELSE 0.00 END  
      ,  SI_ExtFld21 = ISNULL(RTRIM(SI.ExtendedField21),'')  
      ,  SI_ExtFld22 = ISNULL(RTRIM(SI.ExtendedField22),'')  
   FROM #TMP_PACKSKU TMP WITH (NOLOCK)   
   JOIN SKUINFO      SI  WITH (NOLOCK) ON (TMP.Storerkey = SI.Storerkey)  
                                       AND(TMP.Sku  = SI.Sku )  
   WHERE TMP.PickSlipNo = @c_PickSlipNo  
   AND   TMP.MaxSurface Between @n_MaxSurfaceFr AND @n_MaxSurfaceTo   
  
   --WL02 S  
   SET @c_SI_ExtFld22_New = ''  
  
   DECLARE CUR_LOOP CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
      SELECT DISTINCT TP.SI_ExtFld22  
      FROM #TMP_PACKSKU TP  
      WHERE TP.PickSlipNo = @c_PickSlipNo  
      AND   TP.MaxSurface BETWEEN @n_MaxSurfaceFr AND @n_MaxSurfaceTo   
  
   OPEN CUR_LOOP  
  
   FETCH NEXT FROM CUR_LOOP INTO @c_SI_ExtFld22  
  
   WHILE @@FETCH_STATUS <> -1  
   BEGIN  
      SELECT @c_SI_ExtFld22_New = REPLACE(@c_SI_ExtFld22,',','')  
  
      DECLARE CUR_DS CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
         SELECT FDS.ColValue  
         FROM dbo.fnc_DelimSplit(' ', @c_SI_ExtFld22_New) FDS  
         WHERE FDS.ColValue LIKE '%[0-9]N%'  
        
      OPEN CUR_DS  
        
      FETCH NEXT FROM CUR_DS INTO @c_ColValue  
        
      WHILE @@FETCH_STATUS <> -1  
      BEGIN  
         SET @c_ColValue_New = REPLACE(@c_ColValue, 'N', ' Unit')  
  
         SET @c_SI_ExtFld22 = REPLACE(@c_SI_ExtFld22, @c_ColValue, @c_ColValue_New)  
  
         FETCH NEXT FROM CUR_DS INTO @c_ColValue  
      END  
      CLOSE CUR_DS  
      DEALLOCATE CUR_DS  
  
      UPDATE #TMP_PACKSKU  
      SET   #TMP_PACKSKU.SI_ExtFld22 = @c_SI_ExtFld22  
      WHERE #TMP_PACKSKU.PickSlipNo = @c_PickSlipNo  
      AND   #TMP_PACKSKU.MaxSurface Between @n_MaxSurfaceFr AND @n_MaxSurfaceTo   
  
      FETCH NEXT FROM CUR_LOOP INTO @c_SI_ExtFld22  
   END  
   CLOSE CUR_LOOP  
   DEALLOCATE CUR_LOOP  
   --WL02 E  
  
   SELECT  
         @c_LGTCC_Company  = ISNULL(RTRIM(Company ),'')  
      ,  @c_LGTCC_Address1 = ISNULL(RTRIM(Address1),'')  
      ,  @c_LGTCC_Address2 = ISNULL(RTRIM(Address2),'')  
      ,  @c_LGTCC_Address3 = ISNULL(RTRIM(Address3),'')  
      ,  @c_LGTCC_Address4 = ISNULL(RTRIM(Address4),'')  
      ,  @c_LGTCC_City     = ISNULL(RTRIM(City),'')  
      ,  @c_LGTCC_State    = ISNULL(RTRIM(State),'')  
      ,  @c_LGTCC_Zip      = ISNULL(RTRIM(Zip),'')  
      ,  @c_LGTCC_Country  = ISNULL(RTRIM(Country),'')  
      ,  @c_LGTCC_Contact1 = ISNULL(RTRIM(Contact1),'')  
      ,  @c_LGTCC_Phone1   = ISNULL(RTRIM(Phone1),'')  
      ,  @c_LGTCC_Email1   = ISNULL(RTRIM(Email1),'')  
      ,  @c_LGTCC_Notes1   = ISNULL(RTRIM(Notes1),'')  
   FROM STORER WITH (NOLOCK)  
   WHERE Storerkey = 'LOGITECHCC'  
  
  
   SELECT TOP 1   
         @c_Orderkey = TMP.Orderkey  
   FROM #TMP_PACKSKU TMP WITH (NOLOCK)   
  
   SELECT @c_OrderGroup = OH.OrderGroup  
      ,   @c_Vessel = CASE WHEN LEN(OH.Userdefine03)>=3 THEN LEFT(ISNULL(RTRIM(OH.Userdefine03),''),3) ELSE '' END  
      ,   @c_VesselDate = OH.Userdefine06  
      ,   @c_LGTIM_Addr    
                     =  ISNULL(RTRIM(CSG.Company ),'')  + CHAR(13)  
                     +  ISNULL(RTRIM(CSG.Address1),'')  + ' '  
                     +  ISNULL(RTRIM(CSG.Address2),'')  + ' '  
                     +  ISNULL(RTRIM(CSG.Address3),'')  + ' '  
                     +  ISNULL(RTRIM(CSG.Address4),'')  + ' '  
                     +  ISNULL(RTRIM(CSG.City),'')      + ' '  
                   +  ISNULL(RTRIM(CSG.State),'')     + ' '  
                     +  ISNULL(RTRIM(CSG.Zip),'')       + ' '  
                     +  ISNULL(RTRIM(CSG.Country),'')    
      ,   @c_LGTRGST_Addr    
                     =  ISNULL(RTRIM(CSG.B_Company),'') + ' '     
                     +  ISNULL(RTRIM(CSG.B_Address1),'')+ ' '  
                     +  ISNULL(RTRIM(CSG.B_Address2),'')+ ' '  
                     +  ISNULL(RTRIM(CSG.B_Address3),'')+ ' '  
                     +  ISNULL(RTRIM(CSG.B_Address4),'')+ ' '  
                     +  ISNULL(RTRIM(CSG.B_City),'')    + ' '  
                     +  ISNULL(RTRIM(CSG.B_State),'')   + ' '  
                     +  ISNULL(RTRIM(CSG.B_Zip),'')    + ' '  
                     +  ISNULL(RTRIM(CSG.B_Country),'')  
   FROM ORDERS       OH WITH (NOLOCK)  
   LEFT JOIN STORER  CSG WITH (NOLOCK) ON (OH.Consigneekey = CSG.Storerkey)  
                                       AND(CSG.Type = '2')   
   WHERE OH.Orderkey = @c_Orderkey                                                                      
  
   --(CLVN01) START--  
   /*IF @c_OrderGroup = 'S01'  
   BEGIN  
      SELECT  
         @c_LGTIM_Addr  = ISNULL(RTRIM(Company ),'') + CHAR(13)  
                        + ISNULL(RTRIM(Address1),'') + ' '   
                        + ISNULL(RTRIM(Address2),'') + ' '   
                        + ISNULL(RTRIM(Address3),'') + ' '   
                        + ISNULL(RTRIM(Address4),'') + ' '   
                        + ISNULL(RTRIM(City),'') + ' '   
                        + ISNULL(RTRIM(State),'') + ' '   
                        + ISNULL(RTRIM(Zip),'') + ' '   
                        + ISNULL(RTRIM(Country),'') + ' '   
      ,  @c_LGTRGST_Addr= ISNULL(RTRIM(B_Company ),'') + ' '    
                        + ISNULL(RTRIM(B_Address1),'') + ' '   
                        + ISNULL(RTRIM(B_Address2),'') + ' '   
                        + ISNULL(RTRIM(B_Address3),'') + ' '   
                        + ISNULL(RTRIM(B_Address4),'') + ' '   
                        + ISNULL(RTRIM(B_City),'') + ' '   
                        + ISNULL(RTRIM(B_State),'') + ' '   
                        + ISNULL(RTRIM(B_Zip),'') + ' '   
                        + ISNULL(RTRIM(B_Country),'') + ' '   
      FROM STORER WITH (NOLOCK)  
      WHERE Storerkey = 'LOGITECHIM'  
   END*/  
   --(CLVN01) END--  
      
   DECLARE CUR_PSLIP CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
   SELECT RowRef  
         ,NoOfCopy = Qty  
   FROM #TMP_PACKSKU TMP  
   WHERE TMP.PickSlipNo = @c_PickSlipNo  
   AND   TMP.MaxSurface BETWEEN @n_MaxSurfaceFr AND @n_MaxSurfaceTo  
  
   OPEN CUR_PSLIP  
     
   FETCH NEXT FROM CUR_PSLIP INTO @n_RowRef  
                                 ,@n_NoOfCopy  
  
   WHILE @@FETCH_STATUS <> -1    
   BEGIN  
      WHILE @n_NoOfCopy > 0   
      BEGIN  
         INSERT INTO #TMP_PRNCOPY  
            (  RowRef   
            )  
         VALUES   
            (  @n_RowRef  
            )  
         SET @n_NoOfCopy = @n_NoOfCopy - 1  
      END  
  
      FETCH NEXT FROM CUR_PSLIP INTO @n_RowRef  
                                    ,@n_NoOfCopy  
   END  
   CLOSE CUR_PSLIP  
   DEALLOCATE CUR_PSLIP  
  
QUIT_SP:  
   SET @dt_PrintDate = @c_VesselDate  
  
   SET @b_NextMonth = 0  
   IF @c_Vessel = 'SEA' AND Day(@dt_PrintDate) > 20   
   BEGIN  
      SET @b_NextMonth = 1  
   END  
  
   IF @c_Vessel IN ('AIR', 'EXP') AND DATEDIFF(DAY, @dt_PrintDate,  EOMONTH(@dt_PrintDate)) < 4  
   BEGIN  
      SET @b_NextMonth = 1  
   END   
  
   IF @b_NextMonth = 1  
   BEGIN  
      SET @dt_PrintDate = EOMONTH(@dt_PrintDate, 1)  
   END  
       
   SELECT     
         MFGBy       = 'MFG. By: '    
                     + ISNULL(RTRIM(ST.B_Company),'')  + ' '  
                     + ISNULL(RTRIM(ST.B_Address1),'') + ' '  
                     + ISNULL(RTRIM(ST.B_Address2),'') + ' '  
                     + ISNULL(RTRIM(ST.B_Address3),'') + ' '  
                     + ISNULL(RTRIM(ST.B_Address4),'') + ' '  
                     + ISNULL(RTRIM(ST.B_City),'')     + ' '  
                     + ISNULL(RTRIM(ST.B_State),'')    + ' '  
                     + ISNULL(RTRIM(ST.B_Zip),'')      + ' '  
                     + ISNULL(RTRIM(ST.B_Country),'')    
      ,  ImportBy    = 'Name and Address of Importer: '   
                     + ISNULL(@c_LGTIM_Addr,'')  
      ,  RegisteredBy= 'Registered Address: '    
                     + ISNULL(@c_LGTRGST_Addr,'')  
      ,  ExtFld21 = 'Generic Name: ' + TMP.SI_ExtFld21  
      ,  Qty = 'Net Quantity: 1 Unit'   --WL02  
      ,  COO = 'Country of Origin: ' + TMP.COO  
      ,  ExtFld22 = 'Package Contains: ' + TMP.SI_ExtFld22   
      --,  N'MRP ' + FORMAT(CONVERT(FLOAT,TMP.SI_ExtFld03), 'C', 'ta-IN') + ' (inclusive of all taxes)'  
      ,  SI_ExtFld03 = N'MRP ' + NCHAR(8377) + ' ' + FORMAT(TMP.SI_ExtFld03, '###,###,##0.00') + ' (Inclusive of all taxes)'  --(Wan02)  
      --,  printdate = 'Month and Year of Import: ' + DATENAME(MONTH, @dt_PrintDate) + ' ' +  DATENAME(YEAR, @dt_PrintDate)   --WL02  
      ,  printdate = 'Month and Year of Manufacture: ' + ISNULL(TMP.ManufactureDT,'')   --WL02   
      ,  Sku = 'VPN: ' + TMP.Sku  
      ,  ComplainTo  = @c_LGTCC_Company               + ' '  
                     + @c_LGTCC_Address1              + ' '  
                     + @c_LGTCC_Address2              + ' '  
                     --+ @c_LGTCC_Address3              + ' '   --WL01  
                     --+ @c_LGTCC_Address4              + ' '   --WL01  
                     --+ @c_LGTCC_City                  + ' '   --WL01  
                     --+ @c_LGTCC_State                 + ' '   --WL01  
                     --+ @c_LGTCC_Zip                   + ' '   --WL01  
                     --+ @c_LGTCC_Country    
      ,  LGTCC_Phone1   = 'Tel: ' + @c_LGTCC_Phone1     
      ,  LGTCC_Email1   = @c_LGTCC_Email1   --ML01    
      ,  LGTCC_Contact1 = 'For customer complaint, please contact: ' + @c_LGTCC_Contact1   
      ,  LGTCC_Notes1 = CASE WHEN OH.Consigneekey = '218793' THEN  'Value for customs purposes. ' + @c_LGTCC_Notes1 ELSE ' ' END   
      ,  MFGBy_UL = '_________'  
      ,  IMPBy_UL = '______________________________'  
      ,  RGSTBy_UL= '____________________'  
      ,  ComplainTo2 = @c_LGTCC_Address3              + ' '   --WL01  
                     + @c_LGTCC_Address4              + ' '   --WL01  
                     + @c_LGTCC_City                  + ' '   --WL01  
                     + @c_LGTCC_State                 + ' '   --WL01  
                     + @c_LGTCC_Zip                   + ' '   --WL01  
                     + @c_LGTCC_Country                       --WL01  
   FROM #TMP_PACKSKU TMP  
   JOIN #TMP_PRNCOPY TMP_PRN ON (TMP.RowRef = TMP_PRN.RowRef)     
   JOIN ORDERS     OH  WITH (NOLOCK) ON (TMP.Orderkey = OH.Orderkey)  
   JOIN STORER     ST  WITH (NOLOCK) ON (OH.Storerkey = ST.Storerkey)  
   LEFT JOIN STORER  CSG WITH (NOLOCK) ON (OH.Consigneekey = CSG.Storerkey)  
                                       AND(CSG.Type = '2')  
   WHERE TMP.PickSlipNo = @c_PickSlipNo  
   AND   TMP.MaxSurface BETWEEN @n_MaxSurfaceFr AND @n_MaxSurfaceTo  
  
   WHILE @@TRANCOUNT < @n_StartTCnt  
   BEGIN  
      BEGIN TRAN  
   END  
  
END -- procedure  
  
  



GO