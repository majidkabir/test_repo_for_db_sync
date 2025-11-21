SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: isp_INSERT_BTB_ShipmentDetail                           */
/* Creation Date: 22-MAR-2017                                           */
/* Copyright: LF Logistics                                              */
/* Written by: WAn                                                      */
/*                                                                      */
/* Purpose: WMS-1258 - Back-to-Back FTA Entry                           */
/*        :                                                             */
/* Called By: nep_n_cst_btb_shipmentdetail.ue_populatefrombusobj        */
/*          :                                                           */
/* PVCS Version: 1.6                                                    */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/* 08-NOV-2017 Wan01    1.1   WMS-3321 - Triple - Back to Back FTA Entry*/
/* 09-NOV-2018 Wan02    1.2   Fixed. Create New List if                 */
/*                            MaxDetailPerCOO >= 50                     */ 
/* 2020-06-16  Wan03    1.3   WMS-13409 - SG - Logitech - Back to Back  */
/*                            Declaration for Form DE                   */        
/* 2020-OCT-14 NJOW01   1.4   WMS-15167 add externorderkey to           */
/*                            BTBShipmentdetail                         */
/* 2021-JAN-13 WAN04    1.5   WMS-15957-SG-CBF - BTB Form E Declaration */
/* 2021-Dec-09 WLChooi  1.6   DevOps Combine Script                     */
/* 2021-Dec-09 WLChooi  1.6   WMS-18489 SG - LOGITECH - Back to Back    */
/*                            Declaration (WL01)                        */
/************************************************************************/
CREATE PROC [dbo].[isp_INSERT_BTB_ShipmentDetail]
           @c_Wavekey         NVARCHAR(10)
         , @c_BTB_ShipmentKey NVARCHAR(10)
         , @b_Success         INT            OUTPUT
         , @n_Err             INT            OUTPUT
         , @c_ErrMsg          NVARCHAR(255)  OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  
           @n_StartTCnt          INT
         , @n_Continue           INT 

         , @c_BTB_ShipmentListNo NVARCHAR(10)
         , @c_BTB_ShipmentLineNo NVARCHAR(5)
         , @c_ListGroup_Prev     INT
         , @c_ListGroup          INT
         , @c_COO                NVARCHAR(20)
         , @c_HSCode             NVARCHAR(20)
         , @c_Storerkey          NVARCHAR(30)
         , @c_Sku                NVARCHAR(20)
         , @c_SkuDescr           NVARCHAR(60)
         , @c_UOM                NVARCHAR(10)
         , @n_UnitPrice          FLOAT
         , @c_Currency           NVARCHAR(10)
         , @n_QtyExported        INT
         , @n_TotalQtyExported   INT         = 0   --(Wan03)
         , @c_ExternOrderkey     NVARCHAR(50)  --NJOW01
         
         , @n_RowRef             INT          = 0           --(Wan04)
         , @n_QtyBalance         INT          = 0           --(Wan04)
         , @n_QtySplit           INT          = 0           --(Wan04)
         , @c_FormType           NVARCHAR(20) = ''          --(Wan04)
         , @c_FormNo             NVARCHAR(20) = ''          --(Wan04)     

         , @c_PermitNo           NVARCHAR(20) = ''          --(Wan04)
         , @dt_IssuedDate        DATETIME     = '1900-01-01'--(Wan04)
         , @c_IssueCountry       NVARCHAR(30) = ''          --(Wan04)
         , @c_IssueAuthority     NVARCHAR(100)= ''          --(Wan04)                                        --    
         , @c_CustomLotNo        NVARCHAR(20) = ''          --(Wan04)

         --(Wan01) - START
         , @c_BTBShipItem        NVARCHAR(50)

         , @c_SQL                NVARCHAR(MAX)
         , @c_SQLParms           NVARCHAR(MAX)
         , @c_SQLSku             NVARCHAR(255)
         , @c_SQLSkuDescr        NVARCHAR(255)
         , @c_SQLCOO             NVARCHAR(255)
         , @c_SQLHSCode          NVARCHAR(255)
         , @c_SQLCurrency        NVARCHAR(255)   
         , @c_SQLPrice           NVARCHAR(255) 
         , @c_SQLCustomLotNo     NVARCHAR(255) = ''         --(Wan04)

         , @c_Facility           NVARCHAR(5)
         , @c_BTBShipmentByItem  NVARCHAR(30)
         , @c_ItemColName        NVARCHAR(50)
         , @c_ItemColNames       NVARCHAR(250)

         , @n_Cnt                INT
         , @c_TableName          NVARCHAR(30)
         , @c_ColName            NVARCHAR(30)

         , @c_FrColName          NVARCHAR(30)
         , @c_ToColName          NVARCHAR(30)

         , @CUR_COL              CURSOR

         , @n_MaxDetailPerCOO    INT

         , @c_SKUSUSR5           NVARCHAR(50)   = ''   --WL01
         , @c_CCountry           NVARCHAR(100)  = ''   --WL01
         , @c_CountryList        NVARCHAR(4000) = ''   --WL01
   --(Wan01) - END
   
   --(Wan04) - START
   DECLARE @tFormNo           TABLE 
      (  RowRef               INT          IDENTITY(1,1) PRIMARY KEY 
      ,  FormNo               NVARCHAR(20) NOT NULL DEFAULT('')
      ,  FormType             NVARCHAR(10) NOT NULL DEFAULT('')  
      ,  PermitNo             NVARCHAR(20) NOT NULL DEFAULT('')       
      ,  IssuedDate           DATETIME     
      ,  IssueCountry         NVARCHAR(30) NOT NULL DEFAULT('')
      ,  IssueAuthority       NVARCHAR(100)NOT NULL DEFAULT('')
      ,  CustomLotNo          NVARCHAR(20) NOT NULL DEFAULT('')
      ,  QtyBalance           INT          NOT NULL DEFAULT(0)
      )
   --(Wan04) - END

   --(Wan03) - START
   IF OBJECT_ID('tempdb..#BTBSHIPSKU','U') IS NOT NULL
   BEGIN
      DROP TABLE #BTBSHIPSKU;
   END

   CREATE TABLE #BTBSHIPSKU
      (  Wavekey           NVARCHAR(10)   NOT NULL DEFAULT('')
      ,  Storerkey         NVARCHAR(15)   NOT NULL DEFAULT('')
      ,  Sku               NVARCHAR(20)   NOT NULL DEFAULT('')
      ,  HSCode            NVARCHAR(20)   NOT NULL DEFAULT('')
      ,  COO               NVARCHAR(20)   NOT NULL DEFAULT('')
      ,  BTBShipItem       NVARCHAR(50)   NOT NULL DEFAULT('')
      ,  TotalQtyExported  INT            NOT NULL DEFAULT(0)
      ,  ExternOrderkey    NVARCHAR(50)   NOT NULL DEFAULT('')  --NJOW01
      ,  CustomLotNo       NVARCHAR(20)   NOT NULL DEFAULT('')    --(Wan04)
      )
   CREATE INDEX IX_TMP_BTBSHIPSKU on #BTBSHIPSKU ( Wavekey, Storerkey, Sku, HSCode, COO, BTBShipItem )
   --(Wan03) - END

   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_Continue = 1
   SET @n_err      = 0
   SET @c_errmsg   = ''

   --(Wan01) - START
   SET @c_SQLSku      = ''
   SET @c_SQLSkuDescr = ''
   SET @c_SQLCOO      = ''
   SET @c_SQLHSCode   = ''
   SET @c_SQLCurrency = ''
   SET @c_SQLPrice    = ''
   SET @c_ItemColNames= ''
   
   SET @c_Facility = ''
   SET @c_Storerkey= ''

   SET @n_MaxDetailPerCOO = 0

   SELECT TOP 1 
         @c_Facility = OH.Facility    
      ,  @c_Storerkey= OH.Storerkey       
   FROM WAVEDETAIL WD WITH (NOLOCK)
   JOIN ORDERS     OH WITH (NOLOCK) ON (WD.Orderkey = OH.Orderkey)
   WHERE WD.Wavekey = @c_Wavekey

   SET @b_Success = 1
   SET @c_BTBShipmentByItem = ''
   EXEC nspGetRight      
         @c_Facility  = @c_Facility     
      ,  @c_StorerKey = @c_StorerKey      
      ,  @c_sku       = NULL      
      ,  @c_ConfigKey = 'BTBShipmentByItem'      
      ,  @b_Success   = @b_Success              OUTPUT      
      ,  @c_authority = @c_BTBShipmentByItem    OUTPUT      
      ,  @n_err       = @n_err                  OUTPUT      
      ,  @c_errmsg    = @c_errmsg               OUTPUT
      ,  @c_Option1   = @c_ItemColName          OUTPUT 

   IF @b_Success <> 1
   BEGIN
      SET @n_Continue = 3
      SET @n_Err = 63510
      SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err)  
                  + ': Error Executing nspGetRight. (isp_INSERT_BTB_ShipmentDetail)'  
      GOTO QUIT_SP
   END
   
   IF @c_BTBShipmentByItem = '1'
   BEGIN
      SET @c_ItemColNames = ''
     
      SET @CUR_COL = CURSOR FAST_FORWARD READ_ONLY FOR      
      SELECT ColValue = LTRIM(RTRIM(ColValue)) 
      FROM [dbo].[fnc_DelimSplit](',', @c_ItemColName)
      GROUP BY LTRIM(RTRIM(ColValue)) 
      ORDER BY MIN(SeqNo)

      OPEN @CUR_COL

      FETCH NEXT FROM @CUR_COL INTO @c_ItemColName

      WHILE @@FETCH_STATUS = 0
      BEGIN
         IF ISNULL(RTRIM(@c_ItemColName),'') <> ''
         BEGIN
            SET @c_TableName = LEFT(@c_ItemColName, CHARINDEX('.', @c_ItemColName) - 1)                                                                                   
            SET @c_ColName   = REPLACE(@c_ItemColName, @c_TableName + '.', '')                                                            
         
            IF @c_TableName NOT IN ( 'SKU' )
            BEGIN
               SET @n_Continue = 3
               SET @n_Err = 63520
               SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err)  
                           + ': Invalid TableName Setup in Storerconfig ''BTBShipmentByItem'' (isp_INSERT_BTB_ShipmentDetail)'  
               GOTO QUIT_SP
            END
                                                                                                                                               
            SET @n_Cnt = 0                                                                                                                      
            SELECT @n_Cnt = 1                                                                                                                           
            FROM   INFORMATION_SCHEMA.COLUMNS WITH (NOLOCK)                                                                                                                       
            WHERE  TABLE_NAME  = @c_TableName                                                                                                                          
            AND    COLUMN_NAME = @c_ColName  

            IF @n_Cnt = 0 
            BEGIN
               SET @n_Continue = 3
               SET @n_Err = 63530
               SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err)  
                           + ': Invalid Column Name Setup in Storerconfig ''BTBShipmentByItem'' (isp_INSERT_BTB_ShipmentDetail)'  
               GOTO QUIT_SP
            END
         END

         SET @c_ItemColNames = @c_ItemColNames + ' ISNULL(RTRIM( ' + @c_ItemColName + ' ),'''') +'
         FETCH NEXT FROM @CUR_COL INTO @c_ItemColName
      END
   END
   
   IF RIGHT(@c_ItemColNames,1) = '+'
   BEGIN
      SET @c_ItemColNames = LEFT(@c_ItemColNames, LEN(@c_ItemColNames) - 1)
   END

   SET @CUR_COL = CURSOR FAST_FORWARD READ_ONLY FOR      
   SELECT TOColName   = ISNULL(RTRIM(CL.UDF02),'')
         ,FromColName = ISNULL(RTRIM(CL.UDF01),'')
   FROM CODELKUP CL WITH (NOLOCK)
   WHERE CL.ListName = 'BTBPPLFrTo'
   AND   CL.Storerkey = @c_Storerkey

   OPEN @CUR_COL

   FETCH NEXT FROM @CUR_COL INTO @c_ToColName
                              ,  @c_FrColName 

   WHILE @@FETCH_STATUS = 0
   BEGIN
      IF ISNULL(RTRIM(@c_ToColName),'') = '' OR ISNULL(RTRIM(@c_FrColName),'') = ''
      BEGIN
         SET @n_Continue = 3
         SET @n_Err = 63540
         SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err)  
                     + ': Invalid Column Mapping Setup in Codelkup ''BTBPPLFrTo'''
                     + '. Either From or To or Both Column is empty (isp_INSERT_BTB_ShipmentDetail)'  
         GOTO QUIT_SP
      END 

      IF ISNULL(RTRIM(@c_ToColName),'') <> ''
      BEGIN
         SET @c_TableName = ''
         SET @c_ColName   = ''
         SET @c_TableName = LEFT(@c_ToColName, CHARINDEX('.', @c_ToColName) - 1)                                                                                   
         SET @c_ColName   = REPLACE(@c_ToColName, @c_TableName + '.', '')                                                            
  
         IF @c_TableName NOT IN ( 'BTB_SHIPMENTLIST', 'BTB_SHIPMENTDETAIL' )
         BEGIN
            SET @n_Continue = 3
            SET @n_Err = 63550
            SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err)  
                        + ': Invalid TableName Setup in Codelkup ''BTBPPLFrTo''. (isp_INSERT_BTB_ShipmentDetail)'  
            GOTO QUIT_SP
         END
                                                                                                                                                   
         SET @n_Cnt = 0                                                                                                                      
         SELECT @n_Cnt = 1                                                                                                                           
         FROM   INFORMATION_SCHEMA.COLUMNS WITH (NOLOCK)                                                                                                                       
         WHERE  TABLE_NAME  = @c_TableName                                                                                                                          
         AND    COLUMN_NAME = @c_ColName  

         IF @n_Cnt = 0 
         BEGIN
            SET @n_Continue = 3
            SET @n_Err = 63560
            SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err)  
                        + ': Invalid Column Name Setup in Codelkup ''BTBPPLFrTo''. (isp_INSERT_BTB_ShipmentDetail)'  
            GOTO QUIT_SP
         END
      END

      IF ISNULL(RTRIM(@c_FrColName),'') <> ''
      BEGIN
         SET @c_TableName = ''
         SET @c_ColName   = ''
         SET @c_TableName = LEFT(@c_FrColName, CHARINDEX('.', @c_FrColName) - 1)                                                                                   
         SET @c_ColName   = REPLACE(@c_FrColName, @c_TableName + '.', '')                                                            
         
         IF @c_TableName NOT IN ( 'LOTATTRIBUTE', 'SKU', 'SKUINFO', 'ORDERDETAIL', 'WAVEDETAIL', 'PICKDETAIL' )
         BEGIN
            SET @n_Continue = 3
            SET @n_Err = 63570
            SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err)  
                        + ': Invalid TableName Setup in Codelkup ''BTBPPLFrTo''. (isp_INSERT_BTB_ShipmentDetail)'  
            GOTO QUIT_SP
         END
                                                                                                                                                   
         SET @n_Cnt = 0                                                                                                                      
         SELECT @n_Cnt = 1                                                                                                                           
         FROM   INFORMATION_SCHEMA.COLUMNS WITH (NOLOCK)                                                                                                                       
         WHERE  TABLE_NAME  = @c_TableName                                                                                                                          
         AND    COLUMN_NAME = @c_ColName  

         IF @n_Cnt = 0 
         BEGIN
            SET @n_Continue = 3
            SET @n_Err = 63580
            SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err)  
                        + ': Invalid Column Name Setup in Codelkup ''BTBPPLFrTo''. (isp_INSERT_BTB_ShipmentDetail)'  
            GOTO QUIT_SP
         END
      END

      IF CHARINDEX('COO', @c_ToColName) > 1 
      BEGIN
         SET @c_SQLCOO = ' ISNULL(RTRIM( ' + @c_FrColName + ' ),'''')'
      END

      IF CHARINDEX('HSCode', @c_ToColName) > 1 
      BEGIN
         SET @c_SQLHSCode = ' ISNULL(RTRIM( ' + @c_FrColName + ' ),'''')'
      END

      IF CHARINDEX('Price', @c_ToColName) > 1 
      BEGIN
         SET @c_SQLPrice = ' ISNULL( ' + @c_FrColName + ' ), 0.00)'
      END

      IF CHARINDEX('Currency', @c_ToColName) > 1 
      BEGIN
         SET @c_SQLCurrency = ' ISNULL(RTRIM( ' + @c_FrColName + ' ),'''')'
      END
      
      --(Wan04) - START
      IF CHARINDEX('CustomLotNo', @c_ToColName) > 1   
      BEGIN
         SET @c_SQLCustomLotNo = ' ISNULL(RTRIM( ' + @c_FrColName + ' ),'''')'
      END
      --(Wan04) - END
      
      FETCH NEXT FROM @CUR_COL INTO @c_ToColName
                                 ,  @c_FrColName 
   END

   --(Wan04) - START
   SELECT @c_FormType = bs.FormType 
   FROM BTB_Shipment AS bs WITH (NOLOCK)
   WHERE bs.BTB_ShipmentKey = @c_BTB_ShipmentKey
   --(Wan04) - END

   --(Wan03) - START
   INSERT INTO #BTBSHIPSKU
      (  Wavekey
      ,  Storerkey
      ,  Sku
      ,  COO
      ,  HSCode
      ,  BTBShipItem
      ,  TotalQtyExported
      ,  ExternOrderkey
      ,  CustomLotNo                      --(Wan04)
      )
   SELECT BSD.Wavekey
         ,BSD.Storerkey
         ,SKU = CASE WHEN @c_BTBShipmentByItem = '1' THEN '' ELSE BSD.Sku END
         ,BSL.COO
         ,BSD.HSCode
         ,BSD.BTBShipItem
         ,TotalQtyExported = ISNULL(SUM(BSD.QtyExported),0)
         ,ISNULL(BSD.ExternOrderkey,'') --NJOW01
         ,BSD.CustomLotNo                 --(Wan04)
   FROM BTB_SHIPMENTDETAIL BSD WITH (NOLOCK)
   JOIN BTB_SHIPMENT       BSH WITH (NOLOCK) ON BSD.BTB_ShipmentKey = BSH.BTB_ShipmentKey
   JOIN BTB_SHIPMENTLIST   BSL WITH (NOLOCK) ON BSD.BTB_ShipmentKey = BSL.BTB_ShipmentKey
                                            AND BSD.BTB_ShipmentListNo = BSL.BTB_ShipmentListNo
   WHERE BSD.Wavekey = @c_Wavekey
   AND BSH.[Status] = '9'
   GROUP BY BSD.Wavekey
         ,  BSD.Storerkey
         ,  CASE WHEN @c_BTBShipmentByItem = '1' THEN '' ELSE BSD.Sku END
         ,  BSL.COO
         ,  BSD.HSCode
         ,  BSD.BTBShipItem
         ,  ISNULL(BSD.ExternOrderkey,'')  --NJOW01
         ,  BSD.CustomLotNo               --(Wan04)

   --(Wan03) - END

   SET @c_SQLSKU     = CASE WHEN @c_BTBShipmentByItem = '1' THEN '' ELSE ' SKU.Sku' END
   SET @c_SQLSKUDescr= CASE WHEN @c_BTBShipmentByItem = '1' THEN '' ELSE ' ISNULL(RTRIM(SKU.Descr),'''')' END

   IF @c_SQLCOO      = '' SET @c_SQLCOO      = ' ISNULL(RTRIM(LOTATTRIBUTE.Lottable11),'''')'
   IF @c_SQLHSCode   = '' SET @c_SQLHSCode   = ' ISNULL(RTRIM(SKUINFO.ExtendedField01),'''')'
   IF @c_SQLPrice    = '' SET @c_SQLPrice    = ' ISNULL(ORDERDETAIL.UnitPrice,0.00)'
   IF @c_SQLCurrency = '' SET @c_SQLCurrency = ' ISNULL(RTRIM(ORDERDETAIL.UserDefine03),'''')'


   SET @c_SQL =
         N'DECLARE CUR_BTB_SHIP CURSOR FAST_FORWARD READ_ONLY FOR'
      +  ' SELECT ListGroup = DENSE_RANK() OVER ( ORDER BY'
      +                                 @c_SQLCOO + ' )'
      +  ' ,  COO      = ' + @c_SQLCOO 
      +  ' ,  HSCode   = ' + @c_SQLHSCode
      +  ' ,  ORDERDETAIL.Storerkey'
      +  CASE WHEN @c_SQLSku = '' THEN ' ,  Sku = ''''' ELSE ' ,  Sku = ' + @c_SQLSku END
      +  ' ,  SkuDescr = ISNULL(MIN(RTRIM(SKU.Descr)),'''')'  
      --+  CASE WHEN @c_SQLSKUDescr = '' THEN ' ,  SkuDescr = ''''' ELSE ' ,  SkuDescr = ' + @c_SQLSKUDescr END
      +  ' ,  UOM      = ISNULL(RTRIM(PACK.PackUOM3),'''')'
      +  ' ,  UnitPrice= ' + @c_SQLPrice
      +  ' ,  Currency = ' + @c_SQLCurrency
      +  ' ,  QtyExported= SUM(PICKDETAIL.Qty)'
      +  CASE WHEN @c_ItemColNames = '' THEN  ' , BTBShipItem = ''''' ELSE ' , BTBShipItem = ' + @c_ItemColNames END
      +  ' ,  CASE WHEN CONS.Storerkey IS NOT NULL THEN ISNULL(ORDERS.ExternOrderkey,'''') ELSE '''' END ' --NJOW01
      +  ' ,  CustomLotNo =' + CASE WHEN @c_SQLCustomLotNo = '' THEN '''''' ELSE @c_SQLCustomLotNo END     --(Wan04) 
      +  ' ,  C_Country = MAX(ORDERS.C_Country) '   --WL01   
      +  ' FROM WAVEDETAIL   WITH (NOLOCK)'
      +  ' JOIN ORDERDETAIL  WITH (NOLOCK) ON (WAVEDETAIL.Orderkey = ORDERDETAIL.Orderkey)'
      +  ' JOIN PICKDETAIL   WITH (NOLOCK) ON (ORDERDETAIL.Orderkey = PICKDETAIL.Orderkey)'
      +                                  ' AND(ORDERDETAIL.OrderLineNumber = PICKDETAIL.OrderLineNumber)'
      +  ' JOIN SKU          WITH (NOLOCK) ON (PICKDETAIL.Storerkey = SKU.Storerkey)'
      +                                  ' AND(PICKDETAIL.Sku = SKU.Sku)'
      +  ' JOIN PACK         WITH (NOLOCK) ON (SKU.Packkey = PACK.Packkey)'
      +  ' LEFT JOIN SKUINFO WITH (NOLOCK) ON (SKU.Storerkey = SKUINFO.Storerkey)'
      +                                  ' AND(SKU.Sku = SKUINFO.Sku)'
      +  ' JOIN LOTATTRIBUTE WITH (NOLOCK) ON (PICKDETAIL.Lot = LOTATTRIBUTE.Lot)'
      +  ' JOIN ORDERS WITH (NOLOCK) ON (ORDERDETAIL.Orderkey = ORDERS.Orderkey)'  --NJOW01
      +  ' LEFT JOIN STORER CONS (NOLOCK) ON (ORDERS.Consigneekey = CONS.Storerkey AND (CONS.SUSR1=''B2BDN'' OR CONS.SUSR2=''B2BDN'' OR CONS.SUSR3=''B2BDN'' OR CONS.SUSR4=''B2BDN'' OR CONS.SUSR5=''B2BDN''))' --NJOW01
      +  ' WHERE WAVEDETAIL.Wavekey = @c_Wavekey'
      +  CASE WHEN @c_FormType = '' THEN '' ELSE ' AND ORDERS.SpecialHandling = @c_FormType' END   --WL01
      +  ' GROUP BY '+ @c_SQLCOO 
      +         ' , '+ @c_SQLHSCode
      +         ' , ORDERDETAIL.Storerkey'
      +  CASE WHEN @c_SQLSku = '' THEN '' ELSE ' , ' + @c_SQLSku END
      --+  CASE WHEN @c_SQLSkuDescr = '' THEN '' ELSE ' , '+ @c_SQLSkuDescr END
      +         ' ,  ISNULL(RTRIM(PACK.PackUOM3),'''')'
      +  ' , ' + @c_SQLPrice
      +  ' , ' + @c_SQLCurrency
      +  CASE WHEN @c_ItemColNames = '' THEN  '' ELSE ' , ' + @c_ItemColNames END
      + ' , CASE WHEN CONS.Storerkey IS NOT NULL THEN ISNULL(ORDERS.ExternOrderkey,'''') ELSE '''' END ' --NJOW01      
      +  CASE WHEN @c_SQLCustomLotNo = '' THEN '' ELSE ', ' + @c_SQLCustomLotNo END   --(Wan04)
      +  ' ORDER BY COO'
      +        ' ,  Storerkey'
      +        ' ,  Sku'
      +        ' ,  BTBShipItem'
   
   SET @c_SQLParms =
         N'  @c_Wavekey   NVARCHAR(10)'
        + ', @c_FormType  NVARCHAR(10)'   --WL01

   EXEC sp_executesql   @c_SQL
                     ,  @c_SQLParms   
                     ,  @c_Wavekey   
                     ,  @c_FormType   --WL01

   --(Wan01) - END
   OPEN CUR_BTB_SHIP
   
   FETCH NEXT FROM CUR_BTB_SHIP INTO @c_ListGroup             
                                 ,  @c_COO                   
                                 ,  @c_HSCode                
                                 ,  @c_Storerkey             
                                 ,  @c_Sku                   
                                 ,  @c_SkuDescr              
                                 ,  @c_UOM                   
                                 ,  @n_UnitPrice             
                                 ,  @c_Currency              
                                 ,  @n_QtyExported 
                                 ,  @c_BTBShipItem                      --(Wan01)          
                                 ,  @c_ExternOrderkey  --NJOW01
                                 ,  @c_CustomLotNo                      --(Wan04) 
                                 ,  @c_CCountry   --WL01
   BEGIN TRAN
   WHILE @@FETCH_STATUS <> -1
   BEGIN
      --WL01 S
      SELECT @c_SKUSUSR5 = ISNULL(S.SUSR5,'')
      FROM SKU S (NOLOCK)
      WHERE S.StorerKey = @c_Storerkey
      AND S.SKU = @c_Sku
      
      --Check Form D Declaration
      IF @c_FormType = 'D'
      BEGIN 
         IF @c_SKUSUSR5 LIKE 'FORM%'
         BEGIN
            SELECT @c_CountryList = REPLACE(@c_SKUSUSR5, 'FORM' + TRIM(@c_FormType), '')

            IF EXISTS (SELECT 1 FROM dbo.fnc_DelimSplit('-', @c_CountryList) WHERE ColValue = @c_CCountry)
            BEGIN
               IF @c_COO NOT IN ('MY','VN')   --For Form D declarations, allocated lottable11 must be MY or VN
               BEGIN
                  GOTO NEXT_REC
               END
               ELSE
               BEGIN
                  GOTO CONTINUE_EXEC
               END
            END
            ELSE
            BEGIN
               GOTO NEXT_REC
            END
         END
         ELSE
         BEGIN
            GOTO NEXT_REC
         END
      END
      IF @c_FormType = 'E'
      BEGIN
         IF @c_SKUSUSR5 LIKE 'FORM%'
         BEGIN
            SELECT @c_CountryList = REPLACE(@c_SKUSUSR5, 'FORM' + TRIM(@c_FormType), '')

            IF EXISTS (SELECT 1 FROM dbo.fnc_DelimSplit('-', @c_CountryList) WHERE ColValue = @c_CCountry)
            BEGIN
               IF @c_COO NOT IN ('CN')   --For Form E declarations, allocated lottable11 must be CN
               BEGIN
                  GOTO NEXT_REC
               END
               ELSE
               BEGIN
                  GOTO CONTINUE_EXEC
               END
            END
            ELSE
            BEGIN
               GOTO NEXT_REC
            END
         END
         ELSE
         BEGIN
            GOTO NEXT_REC
         END
      END
      ELSE  --@c_FormType NOT IN ('D','E')
      BEGIN
         GOTO NEXT_REC
      END

      CONTINUE_EXEC:
      --WL01 E

      --(Wan03) - START
      SET @n_TotalQtyExported = 0
      SELECT @n_TotalQtyExported = T.TotalQtyExported
      FROM #BTBSHIPSKU T WITH (NOLOCK)
      WHERE T.Wavekey = @c_Wavekey
      AND   T.Storerkey = @c_Storerkey
      AND   T.Sku = @c_Sku
      AND   T.COO = @c_COO
      AND   T.HSCode = @c_HSCode
      AND   T.BTBShipItem = @c_BTBShipItem 
      AND   T.ExternOrderkey = @c_ExternOrderkey --NJOW01
      AND   T.CustomLotNo = @c_CustomLotNo                              --(Wan04)

      IF @n_QtyExported <= @n_TotalQtyExported
      BEGIN
         GOTO NEXT_REC
      END

      SET @n_QtyExported = @n_QtyExported - @n_TotalQtyExported
      --(Wan03) - END

      --(Wan01) - START
      IF  @c_ListGroup_Prev <> @c_ListGroup OR @n_MaxDetailPerCOO >= 50  
      BEGIN 
         SET @c_BTB_ShipmentListNo = ''

         SELECT @c_BTB_ShipmentListNo = BTB_ShipmentListNo  
         FROM BTB_SHIPMENTLIST WITH (NOLOCK)
         WHERE BTB_ShipmentKey = @c_BTB_ShipmentKey
         AND COO = @c_COO
         ORDER BY COO DESC

         SET @n_MaxDetailPerCOO = 0
         SELECT @n_MaxDetailPerCOO = COUNT(1)
         FROM BTB_SHIPMENTDETAIL WITH (NOLOCK)
         WHERE BTB_ShipmentKey = @c_BTB_ShipmentKey
         AND   BTB_ShipmentListNo = @c_BTB_ShipmentListNo

         IF @n_MaxDetailPerCOO >= 50               --(Wan02)
         BEGIN
            SET @n_MaxDetailPerCOO = 0
         END 

         IF @n_MaxDetailPerCOO = 0
         BEGIN
            SELECT @c_BTB_ShipmentListNo = RIGHT('00000' + CONVERT(NVARCHAR(5),(ISNULL(MAX(BTB_ShipmentListNo),0) + 1)),5)
            FROM BTB_SHIPMENTLIST WITH (NOLOCK)
            WHERE BTB_ShipmentKey = @c_BTB_ShipmentKey

            INSERT INTO BTB_SHIPMENTLIST 
                  (  BTB_ShipmentKey
                  ,  BTB_ShipmentListNo
                  ,  Storerkey
                  ,  COO)
            VALUES(  @c_BTB_ShipmentKey
                  ,  @c_BTB_ShipmentListNo
                  ,  @c_Storerkey
                  ,  @c_COO    
                  )

            SET @n_err = @@ERROR 
            IF @n_err <> 0
            BEGIN
               SET @n_Continue = 3
               SET @c_errmsg = CONVERT(CHAR(5),@n_err)
               SET @n_err=80010
               SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Insert Failed Onto Table BTB_SHIPMENTLIST. (isp_INSERT_BTB_ShipmentDetail)' 
                            + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '
               GOTO QUIT_SP
            END
         END
      END 
      --(Wan01) - END
      
      --(Wan04) - START
      SET @c_FormNo        = ''
      SET @c_PermitNo      = ''
      SET @dt_IssuedDate   = '1900-01-01'
      SET @c_IssueCountry  = ''
      SET @c_IssueAuthority= ''  

      IF @c_CustomLotNo <> ''
      BEGIN
      	SELECT @c_FormNo       = ISNULL(MIN(FTA.FormNo),'')           
            , @c_PermitNo       = ISNULL(MIN(FTA.PermitNo),'')         
            , @dt_IssuedDate    = ISNULL(MIN(FTA.IssuedDate),'1900-01-01')     
            , @c_IssueCountry   = ISNULL(MIN(FTA.IssueCountry),'')     
            , @c_IssueAuthority = ISNULL(MIN(FTA.IssueAuthority),'')  
            , @n_QtyBalance     = ISNULL(MIN(FTA.QtyImported - FTA.QtyExported),0)        
      	FROM BTB_FTA FTA WITH (NOLOCK)
      	WHERE FTA.FormType = @c_FormType
         AND FTA.HSCode     = @c_HSCode 	
      	AND FTA.Storerkey  = @c_Storerkey
      	AND FTA.Sku        = @c_Sku    
         AND FTA.BTBShipItem= @c_BTBShipItem     
         AND FTA.CustomLotNo= @c_CustomLotNo 
         AND FTA.IssuedDate > DATEADD(day, -365, GETDATE())
	      AND FTA.EnabledFlag = 'Y' 
	      AND  FTA.QtyImported - FTA.QtyExported > 0 
      	HAVING COUNT(1) = 1	  	
      	
         IF @c_FormNo = ''  --Allocate Matching 1 CustomLotNo and CustomLotNo <> ''
         BEGIN
            SET @c_FormNo        = ''
            SET @c_PermitNo      = ''
            SET @dt_IssuedDate   = '1900-01-01'
            SET @c_IssueCountry  = ''
            SET @c_IssueAuthority= ''  
            SET @n_QtyBalance    = 0
         END
         ELSE
         BEGIN
      	   SET @n_RowRef = 0
      	   SELECT @n_RowRef = tfn.RowRef
      	         ,@n_QtyBalance= tfn.QtyBalance
      	   FROM @tFormNo AS tfn
      	   WHERE tfn.FormNo        = @c_FormNo
      	   AND tfn.FormType        = @c_FormType
      	   AND tfn.PermitNo        = @c_PermitNo
      	   AND tfn.IssuedDate      = @dt_IssuedDate
      	   AND tfn.IssueCountry    = @c_IssueCountry
      	   AND tfn.IssueAuthority  = @c_IssueAuthority
      	   AND tfn.CustomLotNo     = @c_CustomLotNo
      	
      	   IF @n_RowRef = 0
            BEGIN
               INSERT INTO @tFormNo ( FormNo, FormType, PermitNo, IssuedDate, IssueCountry, IssueAuthority, CustomLotNo, QtyBalance )
               VALUES (@c_FormNo, @c_FormType, @c_PermitNo, @dt_IssuedDate, @c_IssueCountry, @c_IssueAuthority, @c_CustomLotNo, @n_QtyBalance)
            END
            ELSE
            BEGIN
         	   UPDATE @tFormNo
         	   SET QtyBalance = CASE WHEN QtyBalance > @n_QtyExported THEN QtyBalance - @n_QtyExported ELSE 0 END
         	   WHERE RowRef = @n_RowRef
         	   
         	   IF @n_QtyBalance = 0  -- Not Enough to allocate, the unique form # already allocated for the same btb_Shipment
               BEGIN
                  SET @c_FormNo        = ''
                  SET @c_PermitNo      = ''
                  SET @dt_IssuedDate   = '1900-01-01'
                  SET @c_IssueCountry  = ''
                  SET @c_IssueAuthority= ''  
               END
            END
         END
      
         SET @n_QtySplit = @n_QtyExported
      
         IF @n_QtyBalance > 0 AND @n_QtyExported > @n_QtyBalance
         BEGIN
            SET @n_QtyExported = @n_QtyBalance
         END
      END
      --(Wan04) - END

      INSERT_DETAIL:
      SET @n_MaxDetailPerCOO = @n_MaxDetailPerCOO + 1                      --(Wan01)
      --SET @c_BTB_ShipmentLineNo = '00001'

      SELECT @c_BTB_ShipmentLineNo = RIGHT('00000' + CONVERT(NVARCHAR(5),(ISNULL(MAX(BTB_ShipmentLineNo),0) + 1)),5)  
      FROM BTB_SHIPMENTDETAIL WITH (NOLOCK)  
      WHERE BTB_ShipmentKey = @c_BTB_ShipmentKey  
      AND   BTB_ShipmentListNo = @c_BTB_ShipmentListNo  
   
      INSERT INTO BTB_SHIPMENTDETAIL 
            (  BTB_ShipmentKey
            ,  BTB_ShipmentListNo
            ,  BTB_ShipmentLineNo
            ,  HSCode                
            ,  IssuedDate  
            ,  Storerkey             
            ,  Sku                    
            ,  SkuDescr              
            ,  UOM                   
            ,  Price             
            ,  Currency              
            ,  QtyExported
            ,  BTBShipItem                                           --(Wan01)
            ,  Wavekey                                               --(Wan01)
            ,  ExternOrderkey  --NJOW01
            ,  CustomLotNo                                           --(Wan04)
            ,  FormNo                                                --(Wan04)  
            ,  PermitNo                                              --(Wan04)
            ,  IssueCountry                                          --(Wan04)
            ,  IssueAuthority                                        --(Wan04)          
            )
      VALUES(  @c_BTB_ShipmentKey
            ,  @c_BTB_ShipmentListNo
            ,  @c_BTB_ShipmentLineNo
            ,  @c_HSCode  
            ,  @dt_IssuedDate                                        --(Wan04)--CONVERT(DATETIME, '1900-01-01')                
            ,  @c_Storerkey             
            ,  @c_Sku                   
            ,  @c_SkuDescr              
            ,  @c_UOM                   
            ,  @n_UnitPrice             
            ,  @c_Currency              
            ,  @n_QtyExported 
            ,  @c_BTBShipItem                                        --(Wan01)  
            ,  @c_Wavekey                                            --(Wan01)  
            ,  @c_ExternOrderkey --NJOW01  
            ,  @c_CustomLotNo                                        --(Wan04)  
            ,  @c_FormNo                                             --(Wan04) 
            ,  @c_PermitNo                                           --(Wan04)
            ,  @c_IssueCountry                                       --(Wan04)
            ,  @c_IssueAuthority                                     --(Wan04)
            )

      SET @n_err = @@ERROR 
      IF @n_err <> 0
      BEGIN
         SET @n_Continue = 3
         SET @c_errmsg = CONVERT(CHAR(5),@n_err)
         SET @n_err=80020
         SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Insert Failed Onto Table BTB_SHIPMENTDETAIL. (isp_INSERT_BTB_ShipmentDetail)' 
                        + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '
         GOTO QUIT_SP
      END

      --(Wan04) - START
      SET @n_QtySplit = @n_QtySplit - @n_QtyExported
      IF @n_QtySplit > 0 
      BEGIN 
         SET @c_FormNo        = ''
         SET @c_PermitNo      = ''
         SET @dt_IssuedDate   = '1900-01-01'
         SET @c_IssueCountry  = ''
         SET @c_IssueAuthority= ''  
         SET @n_QtyBalance    = 0
      	SET @n_QtyExported   = @n_QtySplit
      	GOTO INSERT_DETAIL
      END
      --(Wan04) - END
      
      SET @c_ListGroup_Prev = @c_ListGroup
      NEXT_REC:                                                      --(Wan03)
      FETCH NEXT FROM CUR_BTB_SHIP INTO @c_ListGroup             
                                 ,  @c_COO                   
                                 ,  @c_HSCode                
                                 ,  @c_Storerkey             
                                 ,  @c_Sku                   
                                 ,  @c_SkuDescr              
                                 ,  @c_UOM                   
                                 ,  @n_UnitPrice             
                                 ,  @c_Currency              
                                 ,  @n_QtyExported 
                                 ,  @c_BTBShipItem                   --(Wan01)    
                                 ,  @c_ExternOrderkey  --NJOW01
                                 ,  @c_CustomLotNo                   --(Wan04) 
                                 ,  @c_CCountry   --WL01
   END
   CLOSE CUR_BTB_SHIP
   DEALLOCATE CUR_BTB_SHIP 
QUIT_SP:

   IF CURSOR_STATUS( 'GLOBAL', 'CUR_BTB_SHIP') in (0 , 1)  
   BEGIN
      CLOSE CUR_BTB_SHIP
      DEALLOCATE CUR_BTB_SHIP
   END

   IF CURSOR_STATUS( 'VARIABLE', '@CUR_COL') in (0 , 1)  
   BEGIN
      CLOSE @CUR_COL
      DEALLOCATE @CUR_COL
   END

   IF @n_Continue=3  -- Error Occured - Process And Return
   BEGIN
      SET @b_Success = 0
      IF  @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCnt
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

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'isp_INSERT_BTB_ShipmentDetail'
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
   END
   ELSE
   BEGIN
      SET @b_Success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
   END
END -- procedure

GO