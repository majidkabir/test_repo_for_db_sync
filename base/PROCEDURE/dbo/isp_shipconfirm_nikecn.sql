SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: isp_Shipconfirm_Nikecn                                  */
/* Creation Date: 01-FEB-2018                                           */
/* Copyright: LF Logistics                                              */
/* Written by: Wan                                                      */
/*                                                                      */
/* Purpose: WMS-3812 - [CN-Nike] Direct ship to NFS via BZ-DIG_Shipping */
/*          Confirmation Report Update [CR]                             */
/*        : Move to SP                                                  */
/* Called By:  r_shipconfirm_nikecn                                     */
/*          :                                                           */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/* 07-Feb-2018 Wan01    1.1   Performance Tune                          */
/************************************************************************/
CREATE PROC [dbo].[isp_Shipconfirm_Nikecn]
           @c_Orderkey_Start     NVARCHAR(10)
         , @c_Orderkey_End       NVARCHAR(10)
         , @c_Storerkey_Start    NVARCHAR(15)
         , @c_Storerkey_End      NVARCHAR(15)
         , @dt_Shipdate_Start    DATETIME
         , @dt_Shipdate_End      DATETIME
         , @c_Sku_Start          NVARCHAR(20)
         , @c_Sku_End            NVARCHAR(20)
         , @c_Facility_Start     NVARCHAR(20)
         , @c_Facility_End       NVARCHAR(20)
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @c_SQL1      NVARCHAR(MAX)
         , @c_SQL2      NVARCHAR(MAX) 
         , @c_SQL3      NVARCHAR(MAX) 
         , @c_SQL4      NVARCHAR(MAX) 
         , @c_SQLParm1  NVARCHAR(MAX) 
         , @c_SQLParm2  NVARCHAR(MAX)  
         , @c_SQLParm3  NVARCHAR(MAX) 
         , @c_SQLParm4  NVARCHAR(MAX) 

         , @c_DBName    NVARCHAR(50)
         , @b_GetArchive BIT

   CREATE TABLE #TMP_DC
   (  RowRef            INT   IDENTITY(1,1)     PRIMARY KEY    --(Wan01)
   ,  RowId             INT            NOT NULL 
   ,  DC                NVARCHAR(30)   NULL
   ,  OrderKey          NVARCHAR(10)   NULL  
   ,  Lottable02        NVARCHAR(18)   NULL
   ,  StorerKey         NVARCHAR(15)   NULL
   ,  Sku               NVARCHAR(20)   NULL
   ,  UserDefine04      NVARCHAR(18)   NULL
   ,  OrderQty          INT            NULL
   ,  DelivededQty      INT            NULL
   ,  AccSumQty         INT            NULL
   ,  Variance          INT            NULL
   ,  TotalLineNo       INT            NULL
   )

   CREATE TABLE #TMP_NPCK
   (
      PickSlipNo        NVARCHAR(10)   NOT NULL PRIMARY KEY 
   ,  EditDate          DATETIME       NULL
   )

   CREATE TABLE #TMP_CPCK
   (
      PickSlipNo        NVARCHAR(10)   NOT NULL PRIMARY KEY 
   ,  EditDate          DATETIME       NULL
   )

   CREATE TABLE #TMP_RPT
   (  RowRef            INT   IDENTITY(1,1)     PRIMARY KEY    --(Wan01)
   ,  DC                NVARCHAR(30)   NULL
   ,  ISEG              NVARCHAR(18)   NULL
   ,  StorerKey         NVARCHAR(15)   NULL
   ,  PPL_No            NVARCHAR(30)   NULL 
   ,  SKU               NVARCHAR(20)   NULL 
   ,  VAS_CODE1         NVARCHAR(1000) NULL 
   ,  VAS_CODE2         NVARCHAR(1000) NULL 
   ,  DIVISION          NVARCHAR(10)   NULL  
   ,  EXTERNPOKEY       NVARCHAR(20)   NULL 
   ,  LF_RP_INDICATOR   NVARCHAR(20)   NULL 
   ,  CompleteDate      DATETIME       NULL
   ,  CustomerCode      NVARCHAR(15)   NULL
   ,  PickSlipNo        NVARCHAR(10)   NULL
   ,  OrderQty          INT            NULL
   ,  DelivededQty      INT            NULL
   ,  Variance          INT            NULL
   ,  Status            NVARCHAR(18)   NULL
   ,  Footwear          INT            NULL
   ,  Apparel           INT            NULL
   ,  Equipment         INT            NULL
   ,  Accessory         INT            NULL
   ,  OrderKey          NVARCHAR(10)   NULL
   ,  Ordergroup        NVARCHAR(20)   NULL
   ,  CreationDate      DATETIME       NULL
   ,  ScanIndate        DATETIME       NULL
   ,  PackConfirmDate   DATETIME       NULL  
   ,  NikeOrderNo       NVARCHAR(18)   NULL
   ,  OrdersType        NVARCHAR(10)   NULL
   ,  cDescription      NVARCHAR(250)  NULL
   ,  Loadkey           NVARCHAR(10)   NULL
   )

   SET @c_DBName = ''
   SET @b_GetArchive = 0
   
   INSERT_REC:   
   SET @c_SQL1 = N'SELECT t.RowID'
               + ', ISNULL(t.DC,'''')'
               + ', t.OrderKey'                
               + ', t.Lottable02'         
               + ', t.StorerKey'          
               + ', t.Sku'                
               + ', t.UserDefine04'       
               + ', t.OrderQty'           
               + ', t.DelivededQty'              
               + ' ,AccSumQty = SUM(t.DelivededQty) OVER (PARTITION BY'
               +                                        ' t.OrderKey'
               +                                        ',t.Sku'
               +                                        ' ORDER BY '
               +                                        ' t.Orderkey '
               +                                        ',t.Sku'
               +                                        ',t.RowID'
               +                                        ' )'
               + ' FROM '
               + ' (SELECT RowID = ROW_NUMBER() OVER (PARTITION BY'
               +                                 '  ORDERS.OrderKey'
               +                                 ' ,ORDERDETAIL.Storerkey'
               +                                 ' ,ORDERDETAIL.Sku'
               +                                 '  ORDER BY'
               +                                 '  ORDERS.OrderKey'
               +                                 ' ,ORDERDETAIL.Storerkey'
               +                                 ' ,ORDERDETAIL.Sku'
               +                                 ' ,ISNULL(CL.Code, LOC.PickZone)'
               +                                 ' )'
               + ' ,DC = ISNULL(CL.Code, LOC.PickZone)'
               + ' ,ORDERS.OrderKey'
               + ' ,ORDERDETAIL.Lottable02'
               + ' ,ORDERDETAIL.StorerKey'
               + ' ,ORDERDETAIL.Sku'
               + ' ,ORDERDETAIL.UserDefine04'
               + ' ,OrderQty = (SELECT ISNULL(SUM(OD.OriginalQty),0)'
               +              ' FROM ' + @c_DBName + 'dbo.ORDERS OH WITH (NOLOCK)'                                      --(Wan01)
               +              ' JOIN ' + @c_DBName + 'dbo.ORDERDETAIL OD WITH (NOLOCK) ON (OH.Orderkey = OD.Orderkey)'  --(Wan01)
               +              ' WHERE OH.Orderkey = ORDERS.Orderkey'
               +              ' AND OD.StorerKey = ORDERDETAIL.StorerKey'
               +              ' AND OD.Sku = ORDERDETAIL.Sku)'
               + ' ,DelivededQty = ISNULL(SUM(PICKDETAIL.Qty),0)'
               + ' FROM ' + @c_DBName + 'dbo.ORDERS WITH (NOLOCK)'                                                      --(Wan01)
               + ' JOIN ' + @c_DBName + 'dbo.ORDERDETAIL WITH(NOLOCK) ON (ORDERS.Orderkey = ORDERDETAIL.Orderkey)'      --(Wan01)
               + ' LEFT JOIN ' + @c_DBName + 'dbo.PICKDETAIL  WITH(NOLOCK) ON (ORDERDETAIL.Orderkey = PICKDETAIL.Orderkey)'
               +                                                         ' AND(ORDERDETAIL.OrderLineNumber = PICKDETAIL.OrderLineNumber)'
               + ' LEFT JOIN ' + @c_DBName + 'dbo.LOC         WITH(NOLOCK) ON (PICKDETAIL.Loc = LOC.Loc)'
               + ' LEFT JOIN CODELKUP CL WITH (NOLOCK) ON (CL.ListName = ''ALLSorting'')'
               +                                     ' AND(CL.Storerkey= ORDERDETAIL.Storerkey)'                        --(Wan01)
               +                                     ' AND(CL.Code2    = LOC.PickZone)'
               + ' WHERE ORDERS.OrderKey BETWEEN @c_Orderkey_Start AND @c_Orderkey_End'
               + ' AND   ORDERS.Storerkey BETWEEN @c_Storerkey_Start AND @c_Storerkey_End' 
               + ' AND   ORDERDETAIL.SKU BETWEEN @c_Sku_Start AND @c_Sku_End'                 
               + ' GROUP BY   ORDERS.OrderKey'
               +          ',  ORDERDETAIL.OriginalQty'
               +          ',  ORDERDETAIL.Lottable02'
               +          ',  ORDERDETAIL.StorerKey'
               +          ',  ORDERDETAIL.Sku'
               +          ',  ORDERDETAIL.UserDefine04'
               +          ',  CL.Code'
               +          ',  LOC.PickZone'
               + ') t '
   
   SET @c_SQLParm1 = N'@c_Orderkey_Start  NVARCHAR(10)'
                   + ',@c_Orderkey_End    NVARCHAR(10)'
                   + ',@c_Storerkey_Start NVARCHAR(15)'
                   + ',@c_Storerkey_End   NVARCHAR(15)'
                   + ',@c_Sku_Start       NVARCHAR(20)'
                   + ',@c_Sku_End         NVARCHAR(20)'

   TRUNCATE TABLE #TMP_DC

   INSERT INTO #TMP_DC
         (  RowID
         ,  DC
         ,  OrderKey                
         ,  Lottable02         
         ,  StorerKey          
         ,  Sku                
         ,  UserDefine04       
         ,  OrderQty           
         ,  DelivededQty       
         ,  AccSumQty          
         )
   EXEC sp_ExecuteSQL   @c_SQL1
                     ,  @c_SQLParm1
                     ,  @c_Orderkey_Start  
                     ,  @c_Orderkey_End   
                     ,  @c_Storerkey_Start        
                     ,  @c_Storerkey_End 
                     ,  @c_Sku_Start        
                     ,  @c_Sku_End

  
   UPDATE #TMP_DC 
      SET TotalLineNo = (SELECT COUNT(TMP.DC)
                         FROM #TMP_DC TMP 
                         WHERE TMP.Orderkey = #TMP_DC.Orderkey
                         AND TMP.Sku = #TMP_DC.Sku)

   UPDATE #TMP_DC 
      SET OrderQty = CASE WHEN RowID = TotalLineNo AND OrderQty > AccSumQty THEN OrderQty - AccSumQty ELSE 0 END
                   + DelivededQty
           
   UPDATE #TMP_DC 
      SET Variance = OrderQty - DelivededQty 



   --SET @c_SQL2 = N'SELECT DISTINCT PD.PickSlipNo, MAX(PD.Editdate) AS Editdate' 
   --   +                   ' FROM ' + @c_DBName + 'dbo.PACKDETAIL PD (NOLOCK)'  
   --   +                   ' JOIN ' + @c_DBName + 'dbo.PACKHEADER PH (NOLOCK) ON (PD.PickSlipNo = PH.PickSlipNo)' 
   --   +                   ' JOIN ' + @c_DBName + 'dbo.ORDERS O (NOLOCK) ON (PH.Orderkey = O.Orderkey)'
   --   +                   ' WHERE O.StorerKey BETWEEN @c_Storerkey_Start AND @c_Storerkey_End'
   --   +                   ' AND O.OrderKey BETWEEN @c_Orderkey_Start AND @c_Orderkey_End' 
   --   +                   ' GROUP BY PD.PickSlipNo'

   SET @c_SQL2 = N'SELECT DISTINCT PH.PickSlipNo, PH.Editdate' 
      +                   ' FROM ' + @c_DBName + 'dbo.PACKHEADER PH (NOLOCK)' 
      +                   ' JOIN ' + @c_DBName + 'dbo.ORDERS O (NOLOCK) ON (PH.Orderkey = O.Orderkey)'
      +                   ' WHERE O.StorerKey BETWEEN @c_Storerkey_Start AND @c_Storerkey_End'
      +                   ' AND O.OrderKey BETWEEN @c_Orderkey_Start AND @c_Orderkey_End' 

   SET @c_SQLParm2 = N'@c_Orderkey_Start  NVARCHAR(10)'
                   + ',@c_Orderkey_End    NVARCHAR(10)'
                   + ',@c_Storerkey_Start NVARCHAR(15)'
                   + ',@c_Storerkey_End   NVARCHAR(15)'

   TRUNCATE TABLE #TMP_NPCK

   INSERT INTO #TMP_NPCK
         (  PickSlipNo
         ,  EditDate          
         )
   EXEC sp_ExecuteSQL   @c_SQL2
                     ,  @c_SQLParm2
                     ,  @c_Orderkey_Start  
                     ,  @c_Orderkey_End    
                     ,  @c_Storerkey_Start        
                     ,  @c_Storerkey_End

   --SET @c_SQL3 = N'SELECT DISTINCT PD.PickSlipNo, MAX(PD.Editdate) AS Editdate'  
   --   +                   ' FROM ' + @c_DBName + 'dbo.PACKDETAIL PD (NOLOCK)'  
   --   +                   ' JOIN ' + @c_DBName + 'dbo.PACKHEADER PH (NOLOCK) ON (PD.PickSlipNo = PH.PickSlipNo)'
   --   +                   ' JOIN ' + @c_DBName + 'dbo.ORDERS O (NOLOCK) ON (PH.Loadkey = O.LoadKey)'
   --   +                                                               ' AND(PH.Orderkey = '''')'      --(Wan01)
   --   +                   ' WHERE O.StorerKey BETWEEN @c_Storerkey_Start AND @c_Storerkey_End'
   --   +                   ' AND O.OrderKey BETWEEN @c_Orderkey_Start AND @c_Orderkey_End'
   --   +                   ' GROUP BY PD.PickSlipNo'

   SET @c_SQL3 = N'SELECT DISTINCT PH.PickSlipNo, PH.Editdate'  
      +                   ' FROM ' + @c_DBName + 'dbo.PACKHEADER PH (NOLOCK)'
      +                   ' JOIN ' + @c_DBName + 'dbo.ORDERS O (NOLOCK) ON (PH.Loadkey = O.LoadKey)'
      +                                                               ' AND(PH.Orderkey = '''')'      --(Wan01)
      +                   ' WHERE O.StorerKey BETWEEN @c_Storerkey_Start AND @c_Storerkey_End'
      +                   ' AND O.OrderKey BETWEEN @c_Orderkey_Start AND @c_Orderkey_End'


   SET @c_SQLParm3 = N'@c_Orderkey_Start  NVARCHAR(10)'
                   + ',@c_Orderkey_End    NVARCHAR(10)'
                   + ',@c_Storerkey_Start NVARCHAR(15)'
                   + ',@c_Storerkey_End   NVARCHAR(15)'

  
   TRUNCATE TABLE #TMP_CPCK

   INSERT INTO #TMP_CPCK
         (  PickSlipNo
         ,  EditDate          
         )
   EXEC sp_ExecuteSQL   @c_SQL3
                     ,  @c_SQLParm3
                     ,  @c_Orderkey_Start  
                     ,  @c_Orderkey_End    
                     ,  @c_Storerkey_Start        
                     ,  @c_Storerkey_End
   SET @c_SQL4 = N'SELECT DISTINCT '
      +  ' OD.DC'
      +  ',ISEG = OD.Lottable02'
      +  ',OH.StorerKey' 
      +  ',PPL_No = OH.ExternOrderKey'  
      +  ',OD.SKU'
      +  ',VAS_CODE1 = CASE WHEN ISNULL(ODR.ORDERKEY,''0'') = ''''' 
      +                   ' THEN ''0''' 
      +                   ' ELSE ISNULL(FIRST_VALUE(ODR.NOTE1)' 
      +                        ' OVER (PARTITION BY ODR.ORDERKEY, ODR.PARENTSKU'   
      +                        ' ORDER BY ODR.ORDERKEY ASC),''0'')' 
      +                   ' END' 
      +  ',VAS_CODE2 = CASE WHEN ISNULL(FIRST_VALUE(ODR.NOTE1)' 
      +                        ' OVER (PARTITION BY ODR.PARENTSKU ORDER BY ODR.ORDERKEY ASC),''0'')='
      +                        ' ISNULL(LAST_VALUE(ODR.NOTE1)' 
      +                        ' OVER (PARTITION BY ODR.PARENTSKU ORDER BY ODR.ORDERKEY ASC),''0'')'
      +                   ' THEN ''0'''
      +                   ' ELSE ISNULL(LAST_VALUE(ODR.NOTE1)' 
      +                        ' OVER (PARTITION BY ODR.PARENTSKU ORDER BY ODR.ORDERKEY, ODR.ORDERKEY ASC),''0'')'  
      +                   ' END'
      +  ',DIVISION = OH.Stop' 
      +  ',ISNULL(OH.ExternPOKey,'''')'  
      +  ',LF_RP_INDICATOR = OH.UserDefine05' 
      +  ',CompleteDate = MBOL.EditDate'
      +  ',CustomerCode = OH.ConsigneeKey' 
      +  ',PickSlipNo   = CASE WHEN MAX(NPS.PickHeaderKey) IS NOT NULL'
      +                      ' THEN MAX(NPS.PickHeaderKey)'  
      +                      ' WHEN MAX(CPS.PickHeaderKey) IS NOT NULL'
      +                      ' THEN MAX(CPS.PickHeaderKey)' 
      +                      ' ELSE '' ''' 
      +                      ' END'
      +  ',OrderQty = SUM(OD.OrderQty)' 
      +  ',DelivededQty = SUM(OD.DelivededQty)' 
      +  ',Variance = SUM(OD.Variance)'  
      +  ',Status = CASE WHEN SUM(OD.OrderQty) = SUM(OD.DelivededQty) THEN ''Complete''' 
      +                ' WHEN SUM(OD.OrderQty) > SUM(OD.DelivededQty) THEN ''Partial'''
      +                ' WHEN SUM(OD.DelivededQty) = 0 THEN ''None''' 
      +                ' END'
      +  ',Footwear = SUM(CASE WHEN SKU.SkuGroup = ''FOOTWEAR'' THEN OD.DelivededQty ELSE 0 END)'
      +  ',Apparel  = SUM(CASE WHEN SKU.SkuGroup = ''APPAREL'' THEN OD.DelivededQty ELSE 0 END)'  
      +  ',Equipment= SUM(CASE WHEN SKU.SkuGroup = ''EQUIPMENT'' THEN OD.DelivededQty ELSE 0 END)'
      +  ',Accessory= SUM(CASE WHEN SKU.SkuGroup = ''ACCESSORY'' THEN OD.DelivededQty ELSE 0 END)'   
      +  ',OH.OrderKey'  
      +  ',OH.Ordergroup'
      +  ',CreationDate = MAX(OH.AddDate)' 
      +  ',ScanIndate = CASE WHEN MAX(NPS.PickHeaderKey) IS NOT NULL' 
      +                    ' THEN MAX(NP.ScaninDate)'  
      +                    ' WHEN MAX(CPS.PickHeaderKey) IS NOT NULL' 
      +                    ' THEN MAX(CP.ScaninDate)' 
      +                    ' ELSE '' '' END' 
      +  ',PackConfirmDate= CASE WHEN MAX(NPS.PickHeaderKey) IS NOT NULL' 
      +                        ' THEN NPCK.Editdate' 
      +                        ' WHEN MAX(CPS.PickHeaderKey) IS NOT NULL' 
      +                        ' THEN CPCK.Editdate'
      +                        ' ELSE '' '' END' 
      +  ',NikeOrderNo = OD.UserDefine04'
      +  ',OHType = OH.Type' 
      +  ',cDescr = CL.Long'
      +  ',Loadkey = OH.LoadKey' 
      +  ' FROM ' + @c_DBName + 'dbo.ORDERS OH (NOLOCK)' 
      +  ' JOIN #TMP_DC OD ON (OD.OrderKey = OH.OrderKey)'
      +  ' JOIN ' + @c_DBName + 'dbo.SKU (NOLOCK) ON (OD.StorerKey = SKU.StorerKey)'
      +                                      'AND(OD.Sku = SKU.Sku)'  
      +  ' LEFT JOIN ' + @c_DBName + 'dbo.ORDERDETAILREF ODR (NOLOCK) ON (OH.ORDERKEY = ODR.ORDERKEY)'
      +                                                   ' AND(OH.STORERKEY = ODR.STORERKEY)' 
      +                                                   ' AND(OD.SKU = ODR.PARENTSKU)'
      +  ' LEFT JOIN ' + @c_DBName + 'dbo.PICKHEADER NPS (NOLOCK) ON (NPS.OrderKey = OH.OrderKey'  
      +                                                   ' AND (RTRIM(NPS.OrderKey) IS NOT NULL AND '
      +                                                   ' RTRIM(NPS.OrderKey) <> '''' ))' 
      +  ' LEFT JOIN ' + @c_DBName + 'dbo.PICKHEADER CPS (NOLOCK) ON (CPS.ExternOrderKey = OH.LoadKey' 
      +                                                   ' AND ( RTRIM(CPS.OrderKey) IS NULL OR' 
      +                                                   ' RTRIM(CPS.OrderKey) = '''' ) )' 
      +  ' JOIN ' + @c_DBName + 'dbo.MBOL (NOLOCK) ON (OH.MBOLKey = MBOL.MBOLKey)' 
      +  ' LEFT JOIN ' + @c_DBName + 'dbo.PICKINGINFO NP (NOLOCK) ON (NP.Pickslipno = NPS.Pickheaderkey)'
      +  ' LEFT JOIN ' + @c_DBName + 'dbo.PICKINGINFO CP (NOLOCK) ON (CP.Pickslipno = CPS.Pickheaderkey)'
      +  ' LEFT JOIN #TMP_NPCK NPCK ON (NPCK.PickSlipNo = NPS.PickHeaderKey)'
      +  ' LEFT JOIN #TMP_CPCK CPCK ON (CPCK.PickSlipNo = CPS.PickHeaderKey)'  
      +  ' LEFT JOIN CODELKUP CL (NOLOCK) ON (CL.Code = OH.Type AND CL.LISTNAME = ''ORDERTYPE'' AND CL.Storerkey=OH.StorerKey)' 
      +  ' WHERE MBOL.Status = ''9''' 
      +  ' AND SKU.SkuGroup IN (''FOOTWEAR'', ''APPAREL'', ''EQUIPMENT'', ''ACCESSORY'')' 
      +  ' AND OH.StorerKey BETWEEN @c_Storerkey_Start AND @c_Storerkey_End'
      +  ' AND OD.SKU BETWEEN @c_Sku_Start AND @c_Sku_End' 
      +  ' AND MBOL.EditDate BETWEEN @dt_Shipdate_Start AND @dt_Shipdate_End'  
      +  ' AND OH.OrderKey BETWEEN @c_Orderkey_Start AND @c_Orderkey_End'  
      +  ' AND OH.Facility BETWEEN @c_Facility_Start AND @c_Facility_End'   
      +  ' AND NOT EXISTS (SELECT 1 FROM #TMP_RPT TMP WHERE TMP.Orderkey = OH.Orderkey)'    
      +  ' GROUP BY OD.DC'
      +  ' ,OD.Lottable02'
      +  ' ,OH.StorerKey'
      +  ' ,OH.ExternOrderKey'
      +  ' ,OD.SKU'
      +  ' ,ODR.ORDERKEY'
      +  ' ,ODR.NOTE1'
      +  ' ,ODR.PARENTSKU'
      +  ' ,OH.Stop'
      +  ' ,ISNULL(OH.ExternPOKey,'''')' 
      +  ' ,OH.UserDefine05'
      +  ' ,MBOL.EditDate'
      +  ' ,OH.ConsigneeKey'
      +  ' ,OH.OrderKey'
      +  ' ,OH.Ordergroup'
      +  ' ,NPCK.Editdate'
      +  ' ,CPCK.Editdate'
      +  ' ,OD.UserDefine04'
      +  ' ,OH.Type'
      +  ' ,CL.Long'
      +  ' ,OH.LoadKey'

   SET @c_SQLParm4 = N'@c_Orderkey_Start  NVARCHAR(10)'
                   + ',@c_Orderkey_End    NVARCHAR(10)'
                   + ',@c_Storerkey_Start NVARCHAR(15)'
                   + ',@c_Storerkey_End   NVARCHAR(15)'
                   + ',@dt_Shipdate_Start DATETIME'
                   + ',@dt_Shipdate_End   DATETIME'
                   + ',@c_Sku_Start       NVARCHAR(20)'
                   + ',@c_Sku_End         NVARCHAR(20)'
                   + ',@c_Facility_Start  NVARCHAR(5)'
                   + ',@c_Facility_End    NVARCHAR(5)'

   INSERT INTO #TMP_RPT
         (  DC                
         ,  ISEG              
         ,  StorerKey         
         ,  PPL_No            
         ,  SKU            
         ,  VAS_CODE1         
         ,  VAS_CODE2         
         ,  Division          
         ,  ExternPOKey       
         ,  LF_RP_INDICATOR 
         ,  CompleteDate      
         ,  CustomerCode      
         ,  PickSlipNo        
         ,  OrderQty          
         ,  DelivededQty      
         ,  Variance          
         ,  Status            
         ,  Footwear          
         ,  Apparel           
         ,  Equipment         
         ,  Accessory         
         ,  OrderKey          
         ,  Ordergroup        
         ,  CreationDate      
         ,  ScanIndate        
         ,  PackConfirmDate   
         ,  NikeOrderNo       
         ,  OrdersType        
         ,  cDescription      
         ,  Loadkey           
         )
   EXEC sp_ExecuteSQL   @c_SQL4
                     ,  @c_SQLParm4
                     ,  @c_Orderkey_Start  
                     ,  @c_Orderkey_End 
                     ,  @c_Storerkey_Start
                     ,  @c_Storerkey_End
                     ,  @dt_Shipdate_Start  
                     ,  @dt_Shipdate_End   
                     ,  @c_Sku_Start        
                     ,  @c_Sku_End
                     ,  @c_Facility_Start 
                     ,  @c_Facility_End


   IF @b_GetArchive = 0
   BEGIN
      SET @c_DBName = dbo.fnc_GetArchiveDB()
      SET @b_GetArchive = 1
      IF @c_DBName <> ''
      BEGIN
         GOTO INSERT_REC
      END         
   END

   SELECT SeqNo = ROW_NUMBER() OVER (ORDER BY DC, Loadkey, Orderkey, Storerkey, Sku)
      ,  DC                
      ,  ISEG              
      ,  StorerKey         
      ,  PPL_No            
      ,  SKU            
      ,  VAS_CODE1         
      ,  VAS_CODE2         
      ,  DIVISION          
      ,  ExternPOKey      
      ,  LF_RP_INDICATOR 
      ,  CompleteDate      
      ,  CustomerCode      
      ,  PickSlipNo        
      ,  OrderQty          
      ,  DelivededQty      
      ,  Variance          
      ,  Status            
      ,  Footwear          
      ,  Apparel           
      ,  Equipment         
      ,  Accessory         
      ,  OrderKey          
      ,  Ordergroup        
      ,  CreationDate      
      ,  ScanIndate        
      ,  PackConfirmDate   
      ,  NikeOrderNo       
      ,  OrdersType        
      ,  cDescription      
      ,  Loadkey    
   FROM #TMP_RPT
   ORDER BY DC  
         ,  Loadkey
         ,  Orderkey
         ,  Storerkey
         ,  Sku    

   DROP TABLE #TMP_DC
   DROP TABLE #TMP_RPT
END -- procedure

GO