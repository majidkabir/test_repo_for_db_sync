SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: isp_delivery_note27                                     */
/* Creation Date: 18-MAY-2018                                           */
/* Copyright: LF Logistics                                              */
/* Written by: Wan                                                      */
/*                                                                      */
/* Purpose: WMS-4948 - New RCM Report For Delivery Note DKSH            */
/*        :                                                             */
/* Called By: r_dw_delivery_note27                                      */
/*          :                                                           */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/************************************************************************/
CREATE PROC [dbo].[isp_delivery_note27]
          @c_MBOLKey         NVARCHAR(10) 
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  @c_SQL         NVARCHAR(4000)

         ,  @n_Cnt         INT
         ,  @n_NoOfLine    INT
         ,  @n_RowRef_DN   INT
         ,  @c_Status      NVARCHAR(10)  
         ,  @c_Orderkey    NVARCHAR(10)
         ,  @c_PageNo      NVARCHAR(10)

         ,  @c_DataMartServerDB  NVARCHAR(60)  

         ,  @cur_IL        CURSOR    

   CREATE TABLE #TMP_DN
      (  RowRef         INT      IDENTITY(1,1)  PRIMARY KEY
      ,  MBOLKey        NVARCHAR(10)   NULL
      ,  OrderKey       NVARCHAR(10)   NULL
      ,  Facility       NVARCHAR(5)    NULL
      ,  C_Company      NVARCHAR(45)   NULL
      ,  C_Address1     NVARCHAR(45)   NULL
      ,  C_Address2     NVARCHAR(45)   NULL
      ,  C_Address3     NVARCHAR(45)   NULL
      ,  C_City         NVARCHAR(45)   NULL
      ,  C_Zip          NVARCHAR(18)   NULL 
      ,  C_Country      NVARCHAR(30)   NULL
      ,  C_Phone1       NVARCHAR(18)   NULL 
      ,  Vessel         NVARCHAR(30)   NULL
      ,  ShipDate       DATETIME       NULL 
      ,  ExternOrderkey NVARCHAR(30)   NULL
      ,  ExternPOKey    NVARCHAR(20)   NULL
      ,  ExternLineNo   NVARCHAR(20)   NULL
      ,  Storerkey      NVARCHAR(15)   NULL
      ,  Sku            NVARCHAR(20)   NULL
      ,  Lottable02     NVARCHAR(18)   NULL
      ,  Qty            INT            NULL          
      )  


   CREATE TABLE #TMP_IL
      (  RowRef         INT      IDENTITY(1,1)  PRIMARY KEY
      ,  OrderKey       NVARCHAR(10)   NULL
      ,  PageNo         NVARCHAR(10)   NULL
      ,  ExternLineNo   NVARCHAR(20)   NULL  DEFAULT ('')
      ,  Storerkey      NVARCHAR(15)   NULL  DEFAULT ('')
      ,  Sku            NVARCHAR(20)   NULL  DEFAULT ('')
      ,  Qty            INT            NULL
      ,  Lottable02     NVARCHAR(18)   NULL
      ,  RowRef_DN      INT            NULL
      )

   SET @n_Cnt = 0
   SELECT @n_Cnt = 1
         ,@c_Status = MB.Status  
   FROM MBOL MB WITH (NOLOCK)
   WHERE MB.MBOLKey = @c_MBOLKey

   IF @n_Cnt > 0 AND @c_Status < '9'
   BEGIN
      GOTO QUIT_SP
   END

   IF @n_Cnt = 0
   BEGIN
      SET @c_DataMartServerDB = ''

      SELECT @c_DataMartServerDB = ISNULL(RTRIM(NSQLDescrip),'') FROM NSQLCONFIG WITH (NOLOCK)
      WHERE ConfigKey='DataMartServerDBName'

      IF @c_DataMartServerDB = ''
      BEGIN
         GOTO QUIT_SP
      END

      SET @c_DataMartServerDB = @c_DataMartServerDB + '.ODS.'
   END

   SET @c_SQL = N'SELECT' 
            +'   MB.MBOLkey'
            +' , MB.Facility'
            +' , Vessel = ISNULL(RTRIM(MB.Vessel),'''')'        
            +' , MB.ShipDate'
            +' , OH.Orderkey'
            +' , C_Company  = ISNULL(RTRIM(OH.C_Company),'''')'
            +' , C_Address1 = ISNULL(RTRIM(OH.C_Address1),'''')'      
            +' , C_Address2 = ISNULL(RTRIM(OH.C_Address2),'''')'      
            +' , C_Address3 = ISNULL(RTRIM(OH.C_Address3),'''')'      
            +' , C_City     = ISNULL(RTRIM(OH.C_City),'''') '          
            +' , C_Zip      = ISNULL(RTRIM(OH.C_Zip),'''') '           
            +' , C_Country  = ISNULL(RTRIM(OH.C_Country),'''') '       
            +' , C_Phone1   = ISNULL(RTRIM(OH.C_Phone1),'''')'         
            +' , ExternOrderkey = ISNULL(RTRIM(OH.ExternOrderkey),'''')' 
            +' , ExternPOKey    = ISNULL(RTRIM(OH.ExternPOKey),'''')' 
            +' , ExternLineNo   = ISNULL(RTRIM(OD.ExternLineNo),'''')' 
            +' , OD.Storerkey'       
            +' , OD.Sku'             
            +' , BatchNo = ISNULL(RTRIM(LA.Lottable02),'''')'
            +' , Qty = ISNULL(SUM(PD.Qty),0)'
            +' FROM ' + @c_DataMartServerDB + 'MBOL MB         WITH (NOLOCK)'
            +' JOIN ' + @c_DataMartServerDB + 'MBOLDETAIL MBD  WITH (NOLOCK) ON (MB.MBOLKey = MBD.MBOLKey)'
            +' JOIN ' + @c_DataMartServerDB + 'ORDERS OH       WITH (NOLOCK) ON (MBD.Orderkey= OH.Orderkey)'
            +' JOIN ' + @c_DataMartServerDB + 'ORDERDETAIL OD  WITH (NOLOCK) ON (OH.Orderkey = OD.Orderkey)'
            +' JOIN ' + @c_DataMartServerDB + 'PICKDETAIL  PD  WITH (NOLOCK) ON (OD.Orderkey = PD.Orderkey)'
            +                                                              ' AND(OD.OrderLineNumber = PD.OrderLineNumber)'
            +' JOIN ' + @c_DataMartServerDB + 'LOTATTRIBUTE LA WITH (NOLOCK) ON (PD.Lot = LA.Lot)'
            +' WHERE MB.MBOLKey = @c_MBOLKey'
            +' AND MB.Status = ''9'''
            +' GROUP BY MB.MBOLkey'
            +        ', MB.Facility'
            +        ', ISNULL(RTRIM(MB.Vessel),'''')'          
            +        ', MB.ShipDate'
            +        ', OH.Orderkey'
            +        ', ISNULL(RTRIM(OH.C_Company),'''') '  
            +        ', ISNULL(RTRIM(OH.C_Address1),'''')'      
            +        ', ISNULL(RTRIM(OH.C_Address2),'''')'       
            +        ', ISNULL(RTRIM(OH.C_Address3),'''')'       
            +        ', ISNULL(RTRIM(OH.C_City),'''')'           
            +        ', ISNULL(RTRIM(OH.C_Zip),'''')'            
            +        ', ISNULL(RTRIM(OH.C_Country),'''')'        
            +        ', ISNULL(RTRIM(OH.C_Phone1),'''')'         
            +        ', ISNULL(RTRIM(OH.ExternOrderkey),'''')'  
            +        ', ISNULL(RTRIM(OH.ExternPOKey),'''')'     
            +        ', ISNULL(RTRIM(OD.ExternLineNo),'''')'    
            +        ', OD.Storerkey'       
            +        ', OD.Sku'             
            +        ', ISNULL(RTRIM(LA.Lottable02),'''')'

   INSERT INTO #TMP_DN
      (
         MBOLkey 
      ,  Facility    
      ,  Vessel    
      ,  ShipDate  
      ,  Orderkey 
      ,  C_Company     
      ,  C_Address1     
      ,  C_Address2      
      ,  C_Address3      
      ,  C_City          
      ,  C_Zip           
      ,  C_Country       
      ,  C_Phone1 
      ,  ExternOrderkey  
      ,  ExternPOKey     
      ,  ExternLineNo    
      ,  Storerkey       
      ,  Sku 
      ,  Lottable02
      ,  Qty
      )
   EXEC sp_executesql @c_SQL 
      , N'@c_MBOLKey NVARCHAR(10)' 
      , @c_MBOLKey


   INSERT INTO #TMP_IL
      (  Orderkey
      ,  PageNo 
      ,  ExternLineNo
      ,  Storerkey   
      ,  Sku
      ,  Qty
      ,  Lottable02
      ,  RowRef_DN
      )
   SELECT 
         DN.Orderkey
      --,  PageGroup = DN.OrderKey + '-' +
        , PageNo =
                     CONVERT( NVARCHAR(10),CEILING(ROW_NUMBER() OVER (PARTITION BY 
                                                  DN.MBOLKey       
                                                , DN.OrderKey
                                                ORDER BY DN.MBOLKey       
                                                   , DN.OrderKey  
                                                   , DN.ExternLineNo 
                                                   , DN.StorerKey  
                                                   , DN.Sku
                                     ) / 12.00))
      ,  DN.ExternLineNo
      ,  DN.Storerkey   
      ,  DN.Sku
      ,  DN.Qty   
      ,  DN.Lottable02
      ,  DN.RowRef
   FROM #TMP_DN DN

   SET @cur_IL = CURSOR FAST_FORWARD READ_ONLY FOR
   SELECT Orderkey
         ,PageNo   = MAX(PageNo)
         ,NoOfLine = COUNT(1)
         ,RowRef_DN= MAX(RowRef_DN)
   FROM #TMP_IL
   GROUP BY Orderkey
   ORDER by Orderkey 

   OPEN @cur_IL
   
   FETCH NEXT FROM @cur_IL INTO @c_Orderkey, @c_PageNo, @n_NoOfLine, @n_RowRef_DN
   WHILE @@FETCH_STATUS <> -1
   BEGIN
      WHILE @n_NoOfLine < 12 * @c_PageNo
      BEGIN
         INSERT INTO #TMP_IL
         (  Orderkey
         ,  PageNo
         ,  RowRef_DN
         )
         VALUES 
         (  @c_Orderkey
         ,  @c_PageNo 
         ,  @n_RowRef_DN
         )
         SET @n_NoOfLine = @n_NoOfLine + 1
      END

      FETCH NEXT FROM @cur_IL INTO @c_Orderkey, @c_PageNo, @n_NoOfLine, @n_RowRef_DN 
   END
   CLOSE @cur_IL
   DEALLOCATE @cur_IL 
    
QUIT_SP:
   SELECT  
         SortBy = ROW_NUMBER() OVER (ORDER BY IL.OrderKey
                                           ,  IL.RowRef
                                            --, DN.ExternLineNo 
                                            --, DN.StorerKey  
                                            --, DN.Sku  
                                       ) 

      ,  PageGroup = IL.Orderkey + '-' + IL.PageNo
      ,  DN.MBOLKey       
      ,  DN.OrderKey   
      ,  S_Company = ISNULL(RTRIM(FC.UserDefine01),'')      
      ,  S_Address1= ISNULL(RTRIM(FC.Address1),'')      
      ,  S_Address2= ISNULL(RTRIM(FC.Address2),'')      
      ,  S_Address3= ISNULL(RTRIM(FC.Address3),'')      
      ,  S_City    = ISNULL(RTRIM(FC.City),'')          
      ,  S_Zip     = ISNULL(RTRIM(FC.Zip),'')           
      ,  S_Country = ISNULL(RTRIM(FC.Country),'')
      ,  DN.C_Company       
      ,  DN.C_Address1      
      ,  DN.C_Address2      
      ,  DN.C_Address3      
      ,  DN.C_City          
      ,  DN.C_Zip           
      ,  DN.C_Country
      ,  DN.C_Phone1
      ,  T_Company  = 'PT. LF Services'   
      ,  T_Country  = 'Indonesia'
      ,  ST_Company = ISNULL(RTRIM(ST.Company),'')       
      ,  ST_Address1= ISNULL(RTRIM(ST.Address1),'')
      ,  ST_Address2= ISNULL(RTRIM(ST.Address2),'')
      ,  ST_Address3= ISNULL(RTRIM(ST.Address3),'')
      ,  ST_City    = ISNULL(RTRIM(ST.City),'')    
      ,  ST_Zip     = ISNULL(RTRIM(ST.Zip),'')     
      ,  ST_Country = ISNULL(RTRIM(ST.Country),'') 
      ,  ST_Phone1  = ISNULL(RTRIM(ST.Phone1),'')  
      ,  ST_Fax1    = ISNULL(RTRIM(ST.Fax1),'')    
      ,  DN.Vessel    
      ,  DN.ShipDate 
      ,  DN.ExternOrderkey  
      ,  DN.ExternPOKey     
      ,  IL.ExternLineNo    
      ,  IL.Storerkey       
      ,  IL.Sku
      ,  Descr = ISNULL(RTRIM(SKU.Descr),'')     
      ,  BatchNo = IL.Lottable02
      ,  UnitQty = CASE WHEN PACK.CaseCnt > 0 THEN IL.Qty / PACK.CaseCnt ELSE IL.Qty END
      ,  PackUnit= CASE WHEN SKU.Sku IS NULL 
                        THEN ''
                        ELSE CONVERT(NVARCHAR(10), PACK.CaseCnt) + ' ' + RTRIM(PACK.PACKUOM3) +  '/' + RTRIM(PACK.PACKUOM1)
                        END
      ,  UOM = RTRIM(PACK.PackUOM3)
      ,  Qty = IL.Qty 
   FROM #TMP_IL  IL 
   JOIN #TMP_DN  DN  ON (DN.RowRef = IL.RowRef_DN)
   LEFT JOIN FACILITY FC  WITH (NOLOCK) ON (DN.Facility = FC.Facility)
   LEFT JOIN STORER   ST  WITH (NOLOCK) ON (DN.Storerkey= ST.Storerkey)
   LEFT JOIN SKU          WITH (NOLOCK) ON (IL.Storerkey= SKU.Storerkey)
                                        AND(IL.Sku      = SKU.Sku)
   LEFT JOIN PACK         WITH (NOLOCK) ON (SKU.Packkey = PACK.Packkey)

END -- procedure

GO