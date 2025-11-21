SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*************************************************************************/
/* Stored Procedure: isp_Delivery_Note13_RDT                             */
/* Creation Date: 2014-05-21                                             */
/* Copyright: IDS                                                        */
/* Written by:                                                           */
/*                                                                       */
/* Purpose: SOS#311731 - CN_HM(ECOM)_Delivery Notes                      */
/*                                                                       */
/* Called By: r_dw_delivery_note13_rdt                                   */
/*                                                                       */
/* PVCS Version: 1.1                                                     */
/*                                                                       */
/* Version: 5.4                                                          */
/*                                                                       */
/* Data Modifications:                                                   */
/*                                                                       */
/* Updates:                                                              */
/* Date         Author  Ver   Purposes                                   */
/* 26-Nov-2014  YTwan   1.1   SOS#326750:New Type(3) to print multi pick */
/*                            zone and qty > 1 (Wan01)                   */
/* 28-Nov-2014  YTWan   1.2   SOS#326750:Revise FBR, new type (4), both  */
/*                            type 3 and 4 sort by orderkey (Wan02)      */
/* 02-Jun-2015  NJOW01  1.3   343765 - Add type 2 only print for multiple*/
/*                            pieces                                     */
/* 08-Mar-2016  NJOW02  1.4   365716 - Change field20(size) mapping      */
/* 23-Nov-2016  CSCHONG 1.5   WMS-667- Change field20(size)              */
/*                            & field23(remarks) mapping (CS01)          */
/* 02-JUNE-2017 CSCHONG 1.6   WMS-2049 Add new field (CS02)              */
/* 30-JAN-2018  CSCHONG 1.7   WMS-3813 - Revised report logic (CS03)     */
/* 05-MAY-2020  KuanYee 1.8   INC1132406 - Bug Fix (KY01)                */   
/*************************************************************************/

CREATE PROC [dbo].[isp_Delivery_Note13_RDT] 
         (  @c_Orderkey    NVARCHAR(10)
         ,  @c_Loadkey     NVARCHAR(10)= ''
         ,  @c_Type        NVARCHAR(1) = ''
         ,  @c_DWCategory  NVARCHAR(1) = 'H'
         ,  @n_RecGroup    INT         = 0
         )           
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_DEFAULTS OFF  
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_NoOfLine  INT
         , @n_TotDetail INT
         , @n_LineNeed  INT
         , @n_SerialNo  INT
         , @b_debug     INT
   
   SET @n_NoOfLine = 15
   SET @n_TotDetail= 0
   SET @n_LineNeed = 0
   SET @n_SerialNo = 0
   SET @b_debug    = 0

   IF @c_DWCategory = 'D'
   BEGIN
      GOTO Detail
   END

   HEADER:
      CREATE TABLE #TMP_ORD
            (  SeqNo          INT IDENTITY (1,1)
            ,  Orderkey       NVARCHAR(10) DEFAULT ('')
            ,  TotalShipped   INT         DEFAULT (0)
            ,  Short          NVARCHAR(1) DEFAULT ('N')
            )

      CREATE TABLE #TMP_HDR
            (  SeqNo         INT            
            ,  Orderkey      NVARCHAR(10)
            ,  Storerkey     NVARCHAR(15)
            ,  Company       NVARCHAR(45)
            ,  Phone1        NVARCHAR(18)
            ,  Email1        NVARCHAR(60) 
            ,  B_Company     NVARCHAR(45)
            ,  B_Address1    NVARCHAR(45)
            ,  B_Zip         NVARCHAR(18)
            ,  SUSR5         NVARCHAR(20)
            ,  Notes1        NVARCHAR(4000)
            ,  C_Contact1    NVARCHAR(30)
            ,  C_Address1    NVARCHAR(45)
            ,  C_Address2    NVARCHAR(45)
            ,  C_Address3    NVARCHAR(45)
            ,  C_Zip         NVARCHAR(18)
            ,  C_State       NVARCHAR(45)
            ,  C_City        NVARCHAR(45)
            ,  OrderDate     DATETIME
            ,  BuyerPO       NVARCHAR(20) 
            ,  Notes2        NVARCHAR(4000) 
            ,  Notes2_1      NVARCHAR(4000)
            ,  RI1_UDF01     NVARCHAR(60) 
            ,  RI1_UDF02     NVARCHAR(60) 
            ,  RI1_UDF03     NVARCHAR(60) 
            ,  RI1_UDF04     NVARCHAR(60) 
            ,  RI1_Notes     NVARCHAR(4000)
            ,  RI1_Notes2    NVARCHAR(4000)
            ,  RI2_Long      NVARCHAR(250) 
            ,  RI2_Notes     NVARCHAR(4000)
            ,  RI2_Notes2    NVARCHAR(4000)
            ,  RI3_Long      NVARCHAR(250) 
            ,  RI3_Notes     NVARCHAR(4000)
            ,  RI3_Notes2    NVARCHAR(4000)
            ,  RecGroup      INT
            ,  LPDLineNo     INT                     --CS02
            ,  OrdType       NVARCHAR(10)            --CS03
            ,  TMALLLogo     NVARCHAR(80)            --CS03
            ,  RNotes1       NVARCHAR(250)           --CS03
            ,  RNotes2       NVARCHAR(250)           --CS03
            ,  RNotes3       NVARCHAR(250)           --CS03
            ,  RNotes4       NVARCHAR(250)           --CS03
            ,  RI5_long      NVARCHAR(250)           --CS05
            )

      IF ISNULL(RTRIM(@c_Orderkey),'') = ''
      BEGIN

         INSERT INTO #TMP_ORD
            (  Orderkey
            ,  TotalShipped
            ,  Short
            )
         SELECT PD.Orderkey
               ,SUM(PD.Qty)
               ,(SELECT CASE WHEN SUM(OD.OriginalQty) = SUM(OD.QtyAllocated+OD.QtyPicked+OD.ShippedQty) 
                             THEN 'N' ELSE 'Y' END
                 FROM ORDERDETAIL OD WITH (NOLOCK) 
                 WHERE OD.Orderkey = PD.Orderkey
                 GROUP BY OD.Orderkey)
         FROM LOADPLANDETAIL LPD WITH (NOLOCK)
         JOIN PICKDETAIL     PD  WITH (NOLOCK) ON (LPD.Orderkey = PD.Orderkey)
         JOIN LOC            LOC WITH (NOLOCK) ON (PD.Loc = LOC.Loc)
         WHERE LPD.Loadkey = @c_Loadkey
         GROUP BY PD.Orderkey
         -- SOS#311731: ver 1.6 changed (START)
         HAVING 1 = CASE WHEN @c_Type = '9' AND COUNT (DISTINCT LOC.PickZone) = 1 AND SUM(PD.Qty)> 1 THEN 1 
                         WHEN @c_Type = '1' AND SUM(PD.Qty) = 1  THEN 1
                         WHEN @c_Type = '3' AND COUNT (DISTINCT LOC.PickZone) > 1 AND SUM(PD.Qty)> 1 THEN 1 --(Wan01)
                         WHEN @c_Type = '4' AND COUNT (DISTINCT LOC.PickZone) = 1 THEN 1 --(Wan02)
                         WHEN @c_Type = '2' AND SUM(PD.Qty) > 1 THEN 1 --NJOW01
                         ELSE 0
                         END                                                              
         -- SOS#311731: ver 1.6 changed (END)
         --(Wan02) - START
         --ORDER BY CASE WHEN SUM(PD.Qty) = 1 THEN 1 ELSE 99 END
         --      ,  CASE WHEN SUM(PD.Qty) = 1 THEN MIN(LOC.Logicallocation) ELSE '' END
         --      ,  CASE WHEN SUM(PD.Qty) = 1 THEN MIN(PD.Loc) ELSE '' END
         --      ,  CASE WHEN SUM(PD.Qty) = 1 THEN '' ELSE MIN(PD.Notes) END  -- SOS#311731: ver 1.4 changed 
       ORDER BY   CASE WHEN SUM(PD.Qty) > 1 AND @c_Type IN ('2') THEN MAX(PD.Notes) ELSE '' END  --NJOW01
               ,  CASE WHEN SUM(PD.Qty) > 1 AND @c_Type IN ('2') THEN PD.Orderkey+MAX(PD.Loc) ELSE '' END  --NJOW01
               ,  CASE WHEN SUM(PD.Qty) = 1 AND @c_Type NOT IN ('3', '4') THEN 1 ELSE 99 END
               ,  CASE WHEN SUM(PD.Qty) = 1 AND @c_Type NOT IN ('3', '4') THEN MIN(LOC.Logicallocation) ELSE '' END
               ,  CASE WHEN SUM(PD.Qty) = 1 AND @c_Type NOT IN ('3', '4') THEN MIN(PD.Loc) ELSE '' END 
               ,  CASE WHEN SUM(PD.Qty) = 1 OR  @c_Type IN ('3', '4')     THEN '' ELSE MIN(PD.Notes) END  
         --(Wan02)         
               ,  PD.Orderkey
      END 
      ELSE
      BEGIN
         INSERT INTO #TMP_ORD
            (  Orderkey
            ,  TotalShipped
            ,  Short
            )
         SELECT OD.Orderkey
               ,SUM(OD.QtyAllocated+OD.QtyPicked+OD.ShippedQty)
               ,ShortPicked = CASE WHEN SUM(OD.OriginalQty) = SUM(OD.QtyAllocated+OD.QtyPicked+OD.ShippedQty) 
                                   THEN 'N' ELSE 'Y' END
         FROM ORDERDETAIL OD WITH (NOLOCK)
         WHERE OD.Orderkey = @c_Orderkey
         GROUP BY OD.Orderkey
      END

      INSERT INTO #TMP_HDR
            (  SeqNo   
            ,  Orderkey  
            ,  Storerkey 
            ,  Company      
            ,  Phone1       
            ,  Email1       
            ,  B_Company    
            ,  B_Address1
            ,  B_Zip
            ,  SUSR5   
            ,  Notes1       
            ,  C_Contact1   
            ,  C_Address1   
            ,  C_Address2 
            ,  C_Address3  
            ,  C_Zip    
            ,  C_State     
            ,  C_City       
            ,  OrderDate    
            ,  BuyerPO      
            ,  Notes2     
            ,  Notes2_1   
            ,  RI1_UDF01    
            ,  RI1_UDF02    
            ,  RI1_UDF03    
            ,  RI1_UDF04    
            ,  RI1_Notes    
            ,  RI1_Notes2   
            ,  RI2_Long     
            ,  RI2_Notes    
            ,  RI2_Notes2   
            ,  RI3_Long     
            ,  RI3_Notes    
            ,  RI3_Notes2   
            ,  RecGroup 
            ,  LPDLineNo                           --CS02   
            ,  OrdType
            ,  TMALLLogo
            ,  RNotes1                             --CS03 
            ,  RNotes2                             --CS03 
            ,  RNotes3                             --CS03 
            ,  RNotes4                             --CS03 
            ,  RI5_long                            --CS03
            )
      SELECT DISTINCT 
             TMP.SeqNo
            ,OH.Orderkey
            ,OH.Storerkey
            ,Company    = ISNULL(RTRIM(ST.Company),'')
            ,Phone1     = CASE WHEN ISNULL(OH.[Type],'') <>'TMALLCN' THEN ISNULL(RTRIM(ST.Phone1),'') ELSE ISNULL(RTRIM(ST.Phone2),'')END       --CS03
            ,Email1     = CASE WHEN ISNULL(OH.[Type],'') <>'TMALLCN' THEN dbo.Fnc_Wraptext(ISNULL(RTRIM(ST.Email1),''),26)  
                          ELSE dbo.Fnc_Wraptext(ISNULL(RTRIM(ST.Email2),''),26) END          --CS03
            ,B_Company  = ISNULL(RTRIM(ST.B_Company),'') 
            ,B_Address1 = ISNULL(RTRIM(ST.B_Address1),'') 
            ,B_Zip      = ISNULL(RTRIM(ST.B_Zip),'') 
            ,SUSR5      = ISNULL(RTRIM(ST.SUSR5),'') 
            ,Notes1     = ISNULL(RTRIM(ST.Notes1),'') 
            ,C_Contact1 = ISNULL(RTRIM(OH.C_Contact1),'') 
            ,C_Address1 = ISNULL(RTRIM(OH.C_Address1),'') 
            ,C_Address2 = ISNULL(RTRIM(OH.C_Address2),'') 
            ,C_Address2 = ISNULL(RTRIM(OH.C_Address3),'') 
            ,C_Zip      = ISNULL(RTRIM(OH.C_Zip),'') 
            ,C_State    = ISNULL(RTRIM(OH.C_State),'') 
            ,C_City     = ISNULL(RTRIM(OH.C_City),'') 
            ,OrderDate  = ISNULL(RTRIM(OH.OrderDate),'') 
            ,BuyerPO    = ISNULL(RTRIM(OH.BuyerPO),'') 
            ,Notes2     = dbo.Fnc_Wraptext(ISNULL(RTRIM(MAX(OH.Notes2)),''),25) 
            ,Notes2_1   = dbo.Fnc_Wraptext(ISNULL(RTRIM(MAX(OH.Notes2)),''),40) 
            ,RI1_UDF01  = CASE WHEN ISNULL(OH.[Type],'') <>'TMALLCN' THEN ISNULL(MAX(CASE WHEN CL.Code = '1' THEN RTRIM(Cl.UDF01) ELSE '' END),'')
                          ELSE ISNULL(MAX(CASE WHEN CL.Code = '2' THEN RTRIM(Cl.UDF01) ELSE '' END),'') END      --CS03                                                              
            ,RI1_UDF02  = ISNULL(MAX(CASE WHEN CL.Code = '1' THEN RTRIM(Cl.UDF02) ELSE '' END),'')
            ,RI1_UDF03  = ISNULL(MAX(CASE WHEN CL.Code = '1' THEN RTRIM(Cl.UDF03) ELSE '' END),'')
            ,RI1_UDF04  = ISNULL(MAX(CASE WHEN CL.Code = '1' THEN RTRIM(Cl.UDF04) ELSE '' END),'')
            ,RI1_Notes  = CASE WHEN ISNULL(OH.[Type],'') <>'TMALLCN' THEN ISNULL(MAX(CASE WHEN CL.Code = '1' AND TMP.Short = 'Y' THEN RTRIM(Cl.Notes) ELSE '' END),'')
                          ELSE ISNULL(MAX(CASE WHEN CL.Code = '1' AND TMP.Short = 'Y' THEN RTRIM(Cl.long) ELSE '' END),'') END           --CS03
            ,RI1_Notes2 = CASE WHEN ISNULL(OH.[Type],'') <>'TMALLCN' THEN ISNULL(MAX(CASE WHEN CL.Code = '1' THEN RTRIM(Cl.Notes2) ELSE '' END),'')
                          ELSE ISNULL(MAX(CASE WHEN CL.Code = '5' THEN RTRIM(Cl.Notes2) ELSE '' END),'') END
            ,RI2_Long   = ISNULL(MAX(CASE WHEN CL.Code = '2' THEN RTRIM(Cl.Long) ELSE '' END),'')
            ,RI2_Notes  = ISNULL(MAX(CASE WHEN CL.Code = '2' THEN RTRIM(Cl.Notes) ELSE '' END),'')
            ,RI2_Notes2 = ISNULL(MAX(CASE WHEN CL.Code = '2' AND TMP.Short = 'Y' THEN RTRIM(Cl.Notes2) ELSE '' END),'')
            ,RI3_Long   = ISNULL(MAX(CASE WHEN CL.Code = '3' THEN RTRIM(Cl.Long) ELSE '' END),'')
            ,RI3_Notes  = ISNULL(MAX(CASE WHEN CL.Code = '3' THEN RTRIM(Cl.Notes) ELSE '' END),'')
            ,RI3_Notes2 = ISNULL(MAX(CASE WHEN CL.Code = '3' THEN RTRIM(Cl.Notes2) ELSE '' END),'')
            ,RecGroup   =(Row_Number() OVER (PARTITION BY OH.Orderkey ORDER BY OH.Orderkey,  MIN(CONVERT(INT,OD.ExternLineNo)) Asc)-1)/@n_NoOfLine
				,LPDLineNo  = TMP.SeqNo --CAST(lpd.loadlinenumber AS INT)
				 --CS03 Start
				,OrdType    = ISNULL(OH.[Type],'')
				,HMlogo     = ISNULL(MAX(CASE WHEN CL.Code = '2' THEN RTRIM(Cl.UDF03) ELSE '' END),'')
				,RNotes1    = ISNULL(MAX(CASE WHEN CL.Code = '4' THEN RTRIM(Cl.long) ELSE '' END),'')
				,RNotes2    = ISNULL(MAX(CASE WHEN CL.Code = '4' THEN RTRIM(Cl.Notes) ELSE '' END),'')
				,RNotes3    = ISNULL(MAX(CASE WHEN CL.Code = '4' THEN RTRIM(Cl.Notes2) ELSE '' END),'')
				,RNotes4    = ISNULL(MAX(CASE WHEN CL.Code = '5' THEN RTRIM(Cl.Notes) ELSE '' END),'')
				,RI5_long   = ISNULL(MAX(CASE WHEN CL.Code = '5' THEN RTRIM(Cl.long) ELSE '' END),'')
				--CS03 End
      FROM #TMP_ORD TMP
      JOIN ORDERS      OH WITH (NOLOCK) ON (TMP.Orderkey = OH.Orderkey)
      JOIN STORER      ST WITH (NOLOCK) ON (OH.Storerkey = ST.Storerkey)
      JOIN ORDERDETAIL OD WITH (NOLOCK) ON (OH.Orderkey = OD.Orderkey)
      LEFT JOIN CODELKUP CL WITH (NOLOCK) ON (CL.ListName = 'HMDN' AND CL.Storerkey = OH.Storerkey)
      /*CS02 Start*/
      LEFT JOIN LOADPLANDETAIL LPD WITH (NOLOCK) ON LPD.loadkey = OH.LoadKey AND LPD.orderkey=OH.OrderKey
      /*CS02 End*/
      GROUP BY TMP.SeqNo
            ,  OH.Orderkey
            ,  OH.Storerkey
            ,  ISNULL(RTRIM(ST.Company),'')
            ,  ISNULL(RTRIM(ST.Phone1),'') 
            ,  ISNULL(RTRIM(ST.Phone2),'')                       --CS03
            ,  ISNULL(RTRIM(ST.Email1),'') 
            ,  ISNULL(RTRIM(ST.Email2),'')                       --CS03
            ,  ISNULL(RTRIM(ST.B_Company),'') 
            ,  ISNULL(RTRIM(ST.B_Address1),'') 
            ,  ISNULL(RTRIM(ST.B_Zip),'') 
            ,  ISNULL(RTRIM(ST.SUSR5),'') 
            ,  ISNULL(RTRIM(ST.Notes1),'') 
            ,  ISNULL(RTRIM(OH.C_Contact1),'') 
            ,  ISNULL(RTRIM(OH.C_Address1),'') 
            ,  ISNULL(RTRIM(OH.C_Address2),'') 
            ,  ISNULL(RTRIM(OH.C_Address3),'')
            ,  ISNULL(RTRIM(OH.C_Zip),'') 
            ,  ISNULL(RTRIM(OH.C_State),'') 
            ,  ISNULL(RTRIM(OH.C_City),'') 
            ,  ISNULL(RTRIM(OH.OrderDate),'') 
            ,  ISNULL(RTRIM(OH.BuyerPO),'') 
            ,  OD.Sku
           -- ,  CAST(lpd.loadlinenumber AS INT)           --CS02
           ,  ISNULL(OH.[Type],'')                         --CS03
           
      ORDER BY TMP.SeqNo

IF @b_debug = 1
BEGIN
   INSERT INTO TRACEINFO (TraceName, timeIn, Step1, Step2, step3, step4, step5)
   VALUES ('isp_Delivery_Note13_RDT', getdate(), @c_DWCategory, @c_Loadkey, @c_orderkey, '', suser_name())
END
      
      SELECT Orderkey  
         ,  Storerkey 
         ,  Company      
         ,  Phone1       
         ,  Email1       
         ,  B_Company    
         ,  B_Address1 
         ,  B_Zip 
         ,  SUSR5 
         ,  Notes1       
         ,  C_Contact1   
         ,  C_Address1   
         ,  C_Address2  
         ,  C_Address3 
         ,  C_Zip 
         ,  C_State       
         ,  C_City       
         ,  OrderDate    
         ,  BuyerPO      
         ,  Notes2
         ,  Notes2_1       
         ,  RI1_UDF01    
         ,  RI1_UDF02    
         ,  RI1_UDF03    
         ,  RI1_UDF04    
         ,  RI1_Notes    
         ,  RI1_Notes2   
         ,  RI2_Long     
         ,  RI2_Notes    
         ,  RI2_Notes2   
         ,  RI3_Long     
         ,  RI3_Notes    
         ,  RI3_Notes2   
         ,  RecGroup 
         ,  LPDLineNo                     --CS02 
         ,  OrdType                       --Cs03
         ,  TMALLLogo                     --CS03
         ,  RNotes1 ,RNotes2              --CS03
         ,  RNotes3,RNotes4,RI5_long      --CS03
      FROM #TMP_HDR
      ORDER BY SeqNo                    
      --ORDER BY LPDLineNo
      
      DROP TABLE #TMP_ORD
      DROP TABLE #TMP_HDR
      GOTO QUIT_SP
   DETAIL:
      CREATE TABLE #TMP_ORDSKU
         (  Orderkey       NVARCHAR(10)
         ,  ExternLineNo   INT
         ,  Sku            NVARCHAR(20)
         ,  RecGroup       INT
         )

      CREATE TABLE #TMP_SER
         (  SerialNo       INT
         ,  RecGroup       INT
         ,  Orderkey       NVARCHAR(10)
         ,  Sku            NVARCHAR(20)  
         )

      INSERT INTO #TMP_ORDSKU
         (  Orderkey
         ,  Sku
         ,  ExternLineNo
         ,  RecGroup
         )
      SELECT OD.Orderkey
         ,  OD.SKU
         ,  MIN(CONVERT(INT,OD.ExternLineNo))
         ,  RecGroup   =(Row_Number() OVER (PARTITION BY OD.Orderkey ORDER BY OD.Orderkey,  MIN(CONVERT(INT,OD.ExternLineNo)) Asc) - 1)/@n_NoOfLine
      FROM ORDERDETAIL OD WITH (NOLOCK)   
      WHERE OD.Orderkey = @c_Orderkey
      GROUP BY OD.Orderkey
            ,  OD.Sku 

      INSERT INTO #TMP_SER
         (  SerialNo
         ,  RecGroup
         ,  Orderkey
         ,  Sku 
         )
      SELECT SerialNo= Row_Number() OVER (PARTITION BY TMP.Orderkey ORDER BY TMP.ExternLineNo Asc)
         ,  TMP.RecGroup
         ,  TMP.Orderkey
         ,  TMP.Sku
      FROM #TMP_ORDSKU TMP
      JOIN ORDERDETAIL OD WITH (NOLOCK) ON (TMP.Orderkey = OD.Orderkey)
                                        AND(TMP.Sku = OD.Sku)
      GROUP BY TMP.Orderkey
            ,  TMP.ExternLineNo
            ,  TMP.Sku
            ,  TMP.RecGroup

      SELECT @n_TotDetail = COUNT(1)
            ,@n_SerialNo  = MAX(SerialNo)
      FROM #TMP_SER
      WHERE #TMP_SER.RecGroup = @n_RecGroup

      IF @n_NoOfLine > @n_TotDetail
      BEGIN
         SET @n_LineNeed = @n_NoOfLine - ( @n_SerialNo % @n_NoOfLine )

         WHILE @n_LineNeed > 0
         BEGIN
            SET @n_TotDetail = @n_TotDetail + 1
            SET @n_SerialNo = @n_SerialNo + 1
            INSERT INTO #TMP_SER (SerialNo, RecGroup, Orderkey, Sku)
            VALUES (@n_SerialNo, @n_RecGroup, '', '')
            SET @n_LineNeed = @n_LineNeed - 1  
         END
      END

IF @b_debug = 1
BEGIN
  SELECT @n_SerialNo = MAX(SerialNo)
  FROM #TMP_SER

   INSERT INTO TRACEINFO (TraceName, timeIn, Step1, Step2, step3, step4, step5)
   VALUES ('isp_Delivery_Note13_RDT', getdate(), @c_DWCategory, @c_Loadkey, @c_orderkey, @n_SerialNo, suser_name())
END

      SELECT SerialNo = CASE WHEN LEN(#TMP_SER.SerialNo) < 3 THEN RIGHT('00' + CONVERT(NVARCHAR(2), #TMP_SER.SerialNo),2) ELSE CONVERT(NVARCHAR(10), #TMP_SER.SerialNo) END --(KY01)
                        --RIGHT('00' + CONVERT(NVARCHAR(2), #TMP_SER.SerialNo),2)    
            ,Article = CASE WHEN TMP.Sku IS NULL THEN ''
                       ELSE SUBSTRING(#TMP_SER.Sku,1,7) + '-' + SUBSTRING(#TMP_SER.Sku,8,3) + '-' +  SUBSTRING(#TMP_SER.Sku,11,3)
                       END
            --,[Size]  = ISNULL(MIN(RTRIM(OD.UserDefine03)),'')
            --,[Size] = MIN(CASE WHEN ISNULL(CL.Code,'') <> '' THEN ISNULL(OD.Notes2,'') ELSE ISNULL(OD.Userdefine03,'') END) --NJOW02  --(CS01)
            ,[size]  = MIN(CASE WHEN OD.UserDefine08=ORD.BuyerPO THEN OD.UserDefine06 ELSE OD.Notes2 END)              --(CS01)
            ,OriginalQty = SUM(OD.OriginalQty)
            ,ShippedQty  = SUM(OD.QtyAllocated + OD.QtyPicked + OD.ShippedQty)
           -- ,Remarks =  MIN(ISNULL(RTRIM(OD.UserDefine06),'') + ISNULL(RTRIM(OD.UserDefine07),'') + ' '              --(CS01)
           --         + ISNULL(RTRIM(OD.UserDefine08),'') + ISNULL(RTRIM(OD.UserDefine09),''))                         --(CS01)
           ,Remarks = MIN(CASE WHEN OD.UserDefine08=ORD.BuyerPO THEN (ISNULL(RTRIM(OD.Notes),'') + ' ' +ISNULL(RTRIM(OD.Notes2),'')) ELSE
           	              (ISNULL(RTRIM(OD.UserDefine06),'') + ISNULL(RTRIM(OD.UserDefine07),'') + ' ' +(ISNULL(RTRIM(OD.Notes),'')))END)
           	              
      FROM #TMP_SER
      LEFT JOIN #TMP_ORDSKU TMP  ON (#TMP_SER.RecGroup = TMP.RecGroup)
                                 AND(#TMP_SER.Orderkey = TMP.Orderkey)
                                 AND(#TMP_SER.Sku = TMP.Sku)
      LEFT OUTER JOIN ORDERDETAIL OD WITH (NOLOCK) ON (TMP.Orderkey = OD.Orderkey)
                                             AND(TMP.Sku = OD.Sku)
      LEFT OUTER JOIN ORDERS ORD WITH (NOLOCK) ON ORD.OrderKey = OD.OrderKey                            --(CS01)                                        
      LEFT OUTER JOIN CODELKUP CL WITH (NOLOCK) ON OD.Userdefine03 = CL.Code AND CL.Listname = 'HMR5' AND CL.Storerkey = OD.Storerkey --NJOW02
                          
      WHERE #TMP_SER.RecGroup = @n_RecGroup
      GROUP BY TMP.Orderkey
            ,  TMP.ExternLineNo
            ,  TMP.Sku
            ,  #TMP_SER.Sku
            ,  #TMP_SER.SerialNo
      ORDER BY #TMP_SER.SerialNo


      DROP TABLE #TMP_ORDSKU
      DROP TABLE #TMP_SER
   QUIT_SP:
END       

GO