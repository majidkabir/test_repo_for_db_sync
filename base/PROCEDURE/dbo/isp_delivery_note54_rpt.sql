SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: isp_delivery_note54_rpt                            */
/* Creation Date: 09-JUN-2021                                           */
/* Copyright: IDS                                                       */
/* Written by: CHNOGCS                                                  */
/*                                                                      */
/* Purpose: WMS-17174 [TW]New_BFT_View Report_Delivery Note             */
/*                                                                      */
/* Called By: Report module (r_dw_delivery_note54_rpt)                  */
/*                                                                      */
/* Parameters:                                                          */
/*                                                                      */
/* PVCS Version: 1.2                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/* 2021-12-16   Mingle    1.1   Filter by orderkey/wavekey(ML01)        */
/* 2021-12-16   Mingle    1.1   DevOps Combine Script                   */
/************************************************************************/

CREATE PROCEDURE [dbo].[isp_delivery_note54_rpt]
 @c_Orderkey_start       NVARCHAR(10),
 @c_Orderkey_end         NVARCHAR(10),
 @dt_OrderDateStart      DATETIME = NULL,
 @dt_OrderDateEnd        DATETIME =NULL,
 @dt_DeliverydateStart   DATETIME =NULL,
 @dt_DeliverydateEnd     DATETIME =NULL,
 @c_storerkey            NVARCHAR(20)

AS
BEGIN
   SET NOCOUNT ON    
   SET ANSI_NULLS OFF    
   SET QUOTED_IDENTIFIER OFF    
   SET CONCAT_NULL_YIELDS_NULL OFF  

  DECLARE @c_ExecArguments  NVARCHAR(MAX),
          @c_sql            NVARCHAR(4000),
       --   @c_Storerkey      NVARCHAR(20),
          @c_orderkey       NVARCHAR(20),
          @c_sku            NVARCHAR(20),
          @c_output_Field   NVARCHAR(60)    


  DECLARE 

           @C_col01         NVARCHAR(10)
         , @n_Col01         INT         
         , @c_Col01_Field   NVARCHAR(60)
         , @n_Col02         INT         
         , @c_Col02_Field   NVARCHAR(60)
         , @n_Col03         INT         
         , @c_Col03_Field   NVARCHAR(60)
         , @c_Col13         NVARCHAR(80)
         , @c_GetStorerkey  NVARCHAR(20)
         , @c_GetUserdefine09 NVARCHAR(20)


      CREATE TABLE #TMP_DELNOTE54_ORDERS    
      ( Orderkey     NVARCHAR(10)   NOT NULL     
      , Storerkey    NVARCHAR(15)   NOT NULL    
      , STCompany    NVARCHAR(45)   NULL
      , STContact1   NVARCHAR(45)   NULL  
      ) 

 CREATE TABLE #TMP_DELNOTE54RPT  
      ( STCompany         NVARCHAR(45)   NOT NULL  
      , Storerkey         NVARCHAR(20)   NOT NULL
      , Consigneekey      NVARCHAR(45)  
      , CCompany          NVARCHAR(45)   NOT NULL 
      , Orderkey          NVARCHAR(10)   NOT NULL  
      , C_ADD             NVARCHAR(180)  NULL
      , ORDNOTES          NVARCHAR(800)  NULL   
      , ExternOrderKey    NVARCHAR(50)   
      , BuyerPO           NVARCHAR(20)
      , DeliveryDate      DATETIME
      , OrderDate         DATETIME  
      , SKU               NVARCHAR(30)   NULL    
      , DESCR             NVARCHAR(150) NULL  
      , Casecnt           FLOAT
      , ORDQTY            INT
      , STContact1        NVARCHAR(45) NULL 
      , FIELD13           NVARCHAR(100) NULL 
      , OTHSKU            NVARCHAR(20) NULL
      )  

        SET   @C_col01    = ''
        SET   @n_Col01    = ''         
        SET   @c_Col01_Field  = ''
        SET   @n_Col02        = ''         
        SET   @c_Col02_Field  = ''
        SET   @n_Col03        = ''     
        SET   @c_Col03_Field  = ''
        SET   @c_Col13        = ''

 --SELECT @dt_OrderDateStart '@dt_OrderDateStart'
   
   --START ML01
   CREATE TABLE #TMP_ORDERS (  
    ORDERKEY  NVARCHAR(10),  
   )  
 

  IF EXISTS (SELECT 1 FROM ORDERS WITH (NOLOCK)  
              WHERE Userdefine09 BETWEEN @c_Orderkey_start AND @c_Orderkey_end)  
   BEGIN  
      INSERT INTO #TMP_ORDERS(orderkey)
  	   SELECT ORDERS.ORDERKEY 
      FROM ORDERS WITH (NOLOCK) 
      --JOIN WAVEDETAIL WITH (NOLOCK) ON WAVEDETAIL.OrderKey = ORDERS.OrderKey
  	   WHERE ORDERS.USERDEFINE09 BETWEEN @c_Orderkey_start AND @c_Orderkey_end 
   END             
   ELSE  
   BEGIN  
      INSERT INTO #TMP_ORDERS(orderkey)
  	   SELECT ORDERS.ORDERKEY 
      FROM ORDERS WITH (NOLOCK) 
      WHERE ORDERS.ORDERKEY BETWEEN  @c_Orderkey_start AND @c_Orderkey_end 
   END  
   --END ML01
  


       INSERT INTO #TMP_DELNOTE54_ORDERS    
                  ( Orderkey      
                  , Storerkey   
                  , STCompany
                  , STContact1 
                  )    

   SELECT OH.OrderKey,OH.StorerKey,ISNULL(S.Company,'') ,ISNULL(ST.Contact1,'')
   FROM ORDERS OH WITH (NOLOCK)
   LEFT JOIN dbo.STORER S WITH (NOLOCK) ON S.StorerKey=OH.StorerKey AND S.type='1'
   LEFT JOIN dbo.STORER ST WITH (NOLOCK) ON ST.ConsigneeFor=OH.storerkey AND ST.type='2'
   --JOIN WAVEDETAIL WITH (NOLOCK) ON WAVEDETAIL.OrderKey = OH.OrderKey
   JOIN #TMP_ORDERS t ON OH.orderkey = t.orderkey
   WHERE OH.Orderdate  >= CASE WHEN ISNULL( @dt_OrderDateStart,'') <> '' THEN  @dt_OrderDateStart ELSE OH.Orderdate END
   AND OH.Orderdate  <= CASE WHEN ISNULL(@dt_OrderDateEnd,'') <> '' THEN @dt_OrderDateEnd ELSE OH.Orderdate END
   AND OH.deliverydate  >= CASE WHEN ISNULL( @dt_DeliverydateStart,'') <> '' THEN  @dt_DeliverydateStart ELSE OH.deliverydate END
   AND OH.deliverydate  <= CASE WHEN ISNULL(@dt_DeliverydateEnd,'') <> '' THEN @dt_DeliverydateEnd ELSE OH.deliverydate END
   AND OH.status>='2'
   AND OH.StorerKey = @c_storerkey
   GROUP BY OH.OrderKey,OH.StorerKey,ISNULL(S.Company,''),ST.Contact1
   ORDER BY OH.OrderKey

--SELECT TOP 1 @c_GetStorerkey = t.Storerkey
--FROM #TMP_DELNOTE54_ORDERS t 

--SELECT * FROM #TMP_DELNOTE54_ORDERS

SELECT 
                  @n_Col01      = ISNULL(MAX(CASE WHEN Code = 'Col01' THEN 1 ELSE 0 END),0)
               ,  @c_Col01_Field= ISNULL(MAX(CASE WHEN Code = 'Col01' THEN UDF02 ELSE '' END),'') 
               ,  @n_Col02      = ISNULL(MAX(CASE WHEN Code = 'Col02' THEN 1 ELSE 0 END),0)
               ,  @c_Col02_Field= ISNULL(MAX(CASE WHEN Code = 'Col02' THEN UDF02 ELSE '' END),'')
               ,  @n_Col03      = ISNULL(MAX(CASE WHEN Code = 'Col03' THEN 1 ELSE 0 END),0)
               ,  @c_Col03_Field= ISNULL(MAX(CASE WHEN Code = 'Col03' THEN UDF02 ELSE '' END),'')  
            FROM CODELKUP WITH (NOLOCK) 
            WHERE ListName = 'REPORTCFG'
            AND   Storerkey = @c_storerkey
            AND   Long = 'r_dw_delivery_note54_rpt'
            AND   ISNULL(Short,'') <> 'N'

           SELECT TOP 1 @c_Col13 = CLK.UDF01 
           FROM Codelkup CLK WITH (NOLOCK) 
           WHERE CLK.Listname='REPORTCFG' 
           AND   CLK.Storerkey = @c_storerkey 
           AND   CLK.Long='r_dw_delivery_note54_rpt'


  INSERT INTO #TMP_DELNOTE54RPT
  (
      STCompany,
      Storerkey,
      Consigneekey,
      CCompany,
      Orderkey,
      C_ADD,
      ORDNOTES,
      ExternOrderKey,
      BuyerPO,
      DeliveryDate,
      OrderDate,
      SKU,
      DESCR,
      Casecnt,
      ORDQTY,
      STContact1,
      FIELD13,
      OTHSKU
  )
  SELECT TDN54ORD.STCompany,TDN54ORD.Storerkey,OH.ConsigneeKey,OH.C_Company,TDN54ORD.Orderkey,
         (ISNULL(OH.C_Address1,'') + ISNULL(OH.C_Address2,'') +ISNULL(OH.C_Address3,'') +ISNULL(OH.C_Address4,'')),
        ISNULL(RTRIM(OH.Notes),''),OH.ExternOrderKey,OH.BuyerPO,OH.DeliveryDate,OH.OrderDate,OD.Sku,S.DESCR,P.CaseCnt,
        SUM(PD.Qty),TDN54ORD.STContact1,@c_Col13,''
  FROM #TMP_DELNOTE54_ORDERS TDN54ORD
  JOIN ORDERS OH WITH (NOLOCK) ON OH.OrderKey=TDN54ORD.Orderkey AND OH.StorerKey = TDN54ORD.Storerkey
  JOIN ORDERDETAIL OD WITH (NOLOCK) ON OD.OrderKey=OH.OrderKey
  JOIN SKU AS S WITH (NOLOCK) ON S.Sku = OD.Sku AND S.StorerKey=OD.StorerKey 
  JOIN PACk AS P WITH (NOLOCK) ON P.PackKeY =S.PACKKey
  JOIN PICKDETAIL PD (NOLOCK) on PD.StorerKey = OD.StorerKey and PD.orderkey = OD.orderkey and PD.orderlinenumber = OD.orderlinenumber and PD.SKU = OD.SKU  
  GROUP BY TDN54ORD.STCompany,TDN54ORD.Storerkey,OH.ConsigneeKey,OH.C_Company,TDN54ORD.Orderkey,
         (ISNULL(OH.C_Address1,'') + ISNULL(OH.C_Address2,'') +ISNULL(OH.C_Address3,'') +ISNULL(OH.C_Address4,'')),
        ISNULL(RTRIM(OH.Notes),''),OH.ExternOrderKey,OH.BuyerPO,OH.DeliveryDate,OH.OrderDate,OD.Sku,S.DESCR,P.CaseCnt,
        TDN54ORD.STContact1
 

   DECLARE CUR_DN54GETOTHSKU CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
   SELECT OrderKey    
         ,Storerkey
         ,SKU    
   FROM #TMP_DELNOTE54RPT    
   ORDER BY orderkey    
    
   OPEN CUR_DN54GETOTHSKU    
    
   FETCH NEXT FROM CUR_DN54GETOTHSKU INTO @c_Orderkey    
                                     ,@c_GetStorerkey   
                                     ,@c_sku 
   WHILE @@FETCH_STATUS <> -1    
   BEGIN 

        SET   @c_ExecArguments = ''
        SET   @c_output_Field  =''
        SET   @c_sql             =''

   IF ISNULL(@c_Col01_Field,'')  <> '' AND ISNULL(@c_Col02_Field,'') <> '' AND ISNULL(@c_Col03_Field,'') <> ''
   BEGIN
     
  
         select @c_sql = '
                        select top 1 @c_output_Field = 
                        case when isnull('+@c_Col01_Field+','''') <> '''' then '+@c_Col01_Field+'
                        else 
                        case when isnull('+@c_Col02_Field+' ,'''') <> '''' then '+@c_Col02_Field+'
                        else 
                        case when isnull('+@c_Col03_Field+' ,'''')<>'''' then '+@c_Col03_Field+'
                        else ''N/A'' end end end
                        from sku (nolock) where storerkey = @c_Storerkey and  sku= @c_Sku'
  
        SET @c_ExecArguments = N'@c_Storerkey NVARCHAR(50) , @c_Sku NVARCHAR(20), @c_output_Field NVARCHAR(60) OUTPUT '  


        EXEC sp_executesql @c_sql  
            , @c_ExecArguments  
            , @c_Storerkey   
            , @c_Sku 
            , @c_output_Field OUTPUT

END

   UPDATE #TMP_DELNOTE54RPT
   SET OTHSKU = CASE WHEN ISNULL(@c_output_Field,'') <> '' THEN @c_output_Field ELSE 'N/A' END
   WHERE orderkey = @c_Orderkey_end
   AND  SKU = @c_sku
   AND Storerkey = @c_GetStorerkey
  
   FETCH NEXT FROM CUR_DN54GETOTHSKU INTO @c_Orderkey    
                                     ,@c_GetStorerkey  
                                     ,@c_sku  
   END    
   CLOSE CUR_DN54GETOTHSKU    
   DEALLOCATE CUR_DN54GETOTHSKU    

   SELECT * FROM #TMP_DELNOTE54RPT ORDER BY orderkey, sku
END

GO