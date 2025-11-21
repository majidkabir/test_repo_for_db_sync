SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: isp_Packing_List_43_rpt                                 */
/* Creation Date: 04-MAY-2018                                           */
/* Copyright: LF Logistics                                              */
/* Written by: CSCHONG                                                  */
/*                                                                      */
/* Purpose: WMS-4905 - [CN] DICKIES_EXCEED_PackingList_CR               */
/*        :                                                             */
/* Called By: r_dw_packing_list_43_rpt                                  */
/*          :                                                           */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/* 2021-Apr-09 CSCHONG  1.1   WMS-16024 PB-Standardize TrackingNo (CS01)*/
/************************************************************************/
CREATE PROC [dbo].[isp_Packing_List_43_rpt]
            (@c_loadkey NVARCHAR(10),
             @c_Orderkey  NVARCHAR(20) = '')    
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  
           @n_StartTCnt       INT
         , @n_Continue        INT 
         , @c_isOrdKey        NVARCHAR(5)
         , @c_getOrdKey       NVARCHAR(20) 
         , @c_getloadKey       NVARCHAR(20) 
         , @c_storerkey       NVARCHAR(20)


   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_Continue = 1

   WHILE @@TRANCOUNT > 0
   BEGIN
      COMMIT TRAN
   END
   
   
   CREATE TABLE #TEMPPACKLIST43RPT(
   ID               INT IDENTITY(1,1) NOT NULL,
   Contact1         NVARCHAR(30)   NULL,
   c_addresses      NVARCHAR(200)   NULL,
   C_City           NVARCHAR(18)   NULL,
   loadkey          NVARCHAR(20)   NULL,
   Orderkey         NVARCHAR(20)   NULL,
   MCompany         NVARCHAR(45)   NULL,
   ExternOrderKey   NVARCHAR(20)   NULL,
   TaskBatchNo      NVARCHAR(10)   NULL,
   LogicalName      NVARCHAR(10)   NULL,
   Shipperkey       NVARCHAR(50)   NULL,
   PLOC             NVARCHAR(10)   NULL,
   ordudef04        NVARCHAR(20)   NULL,
   SKU              NVARCHAR(20)   NULL,
   SDESCR           NVARCHAR(150)  NULL,
   AltSKU           NVARCHAR(20)   NULL,
   PQty             INT            NULL,
   ordudef03        NVARCHAR(30)   NULL
   
   )
   
   SET @c_storerkey = ''
   
   SELECT TOP 1 @c_storerkey = OH.storerkey
   FROM ORDERS OH (NOLOCK)
   WHERE OH.loadkey = @c_loadkey
   
    CREATE TABLE #TEMP_ORDERKEY43RPT
    (loadkey    NVARCHAR(20)     NULL, 
     OrderKey    NVARCHAR(10)    NULL
    )

              
      INSERT INTO #TEMP_ORDERKEY43RPT (loadkey,ORDERKEY)
      SELECT DISTINCT OH.loadkey,OH.OrderKey
      FROM ORDERS AS OH WITH (NOLOCK)
      JOIN PICKDETAIL PD (NOLOCK) ON PD.Orderkey = OH.OrderKey
      WHERE OH.LOADKEY=@c_loadkey
      AND OH.OrderKey = CASE WHEN ISNULL(@c_Orderkey,'') <> '' THEN @c_Orderkey ELSE OH.OrderKey END
      AND PD.qty >= 2
      AND OH.[Status] IN ('2','3','5','9')
      AND OH.StorerKey = @c_storerkey
      AND (OH.Shipperkey LIKE '%EMS%' OR OH.Shipperkey LIKE '%JD%' 
          OR OH.Shipperkey LIKE '%SF%' OR OH.Shipperkey LIKE '%STO%' 
          OR OH.Shipperkey LIKE '%ZTO%'OR OH.Shipperkey LIKE '%YTO%')  

      
      DECLARE CUR_ORDKEY CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT loadkey,Orderkey
      FROM #TEMP_ORDERKEY43RPT
      ORDER BY Orderkey

     OPEN CUR_ORDKEY

      FETCH NEXT FROM CUR_ORDKEY INTO @c_getloadKey,@c_getOrdKey
      WHILE @@FETCH_STATUS = 0
      BEGIN
         
            INSERT INTO #TEMPPACKLIST43RPT
            (
               -- ID -- this column value is auto-generated
               Contact1,
               c_addresses,
               C_City,
               loadkey,
               Orderkey,
               MCompany,
               ExternOrderKey,
               TaskBatchNo,
               LogicalName,
               Shipperkey,
               PLOC,
               ordudef04,
               SKU,
               SDESCR,
               AltSKU,
               PQty,
               ordudef03
            )

   
            SELECT  Contact1   =  ISNULL(RTRIM(o.c_Contact1), '')
              ,   c_addresses = ( ISNULL(RTRIM(o.c_Address1), '') 
                             +  ISNULL(RTRIM(o.c_Address2), '') +  ISNULL(RTRIM(o.c_Address3), '') +  ISNULL(RTRIM(o.c_Address4), '') )
              ,   C_city = ISNULL(RTRIM(O.C_city), '') 
              ,   O.loadkey
              ,   O.Orderkey 
              ,   MCompany       =  ISNULL(RTRIM(O.m_Company), '')
              ,   ExternOrderKey = ISNULL(RTRIM(o.ExternOrderkey), '') 
              ,   TaskBatchNo    =  ISNULL(RTRIM(PT.TaskBatchNo), '')                                
              ,   LogicalName    =  ISNULL(RTRIM(PT.LogicalName), '')   
              ,   Shipperkey     =  CASE UPPER(O.ShipperKey) 
                                    WHEN 'YTO' THEN N'YTO-圆通' 
                                    WHEN 'STO' THEN N'STO-申通' 
                                    WHEN 'ZTO' THEN N'ZTO-申通'
                                    WHEN 'SF' THEN N'SF-顺丰'
                                    WHEN 'EMS' THEN N'EMS-邮政'
                                    WHEN 'JD' THEN N'JD-京东'
                                    END                                               
              ,   Ploc           = PD.Loc                            
              ,   ordudef04      = ISNULL(RTRIM(O.TrackingNo), '') --ISNULL(RTRIM(O.userdefine04), '')               --CS01         
              ,   SKU            = OD.Sku
              ,   SDESCR         = S.descr
              ,   Altsku         = S.altsku
              ,   PQty          = sum(PD.Qty)                       
              ,   ordudef03      = CASE LEFT(UPPER(O.userdefine03),1) 
                                    WHEN 'T' THEN N'淘宝订单号:' 
                                    WHEN 'Q' THEN N'QQ商城订单号:' 
                                    ELSE N'交易号:'
                                    END     
            FROM ORDERS     O  WITH (NOLOCK)
            JOIN ORDERDETAIL OD WITH (NOLOCK) ON OD.OrderKey=O.OrderKey
            JOIN PICKDETAIL PD (NOLOCK) ON PD.Orderkey = O.OrderKey
            LEFT JOIN PACKTASK PT (NOLOCK) ON PT.Orderkey = O.OrderKey
            JOIN STORER     ST WITH (NOLOCK) ON (ST.StorerKey = O.Storerkey)
            JOIN SKU         S WITH (NOLOCK) ON (S.Storerkey = OD.Storerkey)
                                             AND(S.Sku = OD.Sku)
            WHERE  O.Orderkey = @c_getOrdKey
            AND O.LoadKey = @c_getloadKey 
            GROUP BY O.Orderkey 
                 ,   ISNULL(RTRIM(o.c_Contact1), '')
                 ,   (ISNULL(RTRIM(o.c_Address1), '') 
                      +  ISNULL(RTRIM(o.c_Address2), '') +  ISNULL(RTRIM(o.c_Address3), '') +  ISNULL(RTRIM(o.c_Address4), '') )
                 ,  ISNULL(RTRIM(O.C_city), '') 
                 ,   O.loadkey
                 ,   O.Orderkey               
                 ,   ISNULL(RTRIM(O.m_Company), ''),ISNULL(RTRIM(o.ExternOrderkey), '') 
                 , ISNULL(RTRIM(PT.TaskBatchNo), '')   
                 , ISNULL(RTRIM(PT.LogicalName), '') 
                 ,CASE UPPER(O.ShipperKey) 
                                    WHEN 'YTO' THEN N'YTO-圆通' 
                                    WHEN 'STO' THEN N'STO-申通' 
                                    WHEN 'ZTO' THEN N'ZTO-申通'
                                    WHEN 'SF' THEN N'SF-顺丰'
                                    WHEN 'EMS' THEN N'EMS-邮政'
                                    WHEN 'JD' THEN N'JD-京东'
                                    END                                               
                 ,  PD.Loc        
                 --,  ISNULL(RTRIM(O.userdefine04), '')      --CS01
                 ,  ISNULL(RTRIM(O.TrackingNo), '')          --CS01
                 , OD.sku 
                 , S.descr
                 ,s.altsku
                 ,CASE LEFT(UPPER(O.userdefine03),1) 
                                       WHEN 'T' THEN N'淘宝订单号:' 
                                       WHEN 'Q' THEN N'QQ商城订单号:' 
                                       ELSE N'交易号:'
                                       END      
      FETCH NEXT FROM CUR_ORDKEY INTO  @c_getloadKey,@c_getOrdKey
      END
      
      
      SELECT   Contact1,
               c_addresses,
               C_City,
               loadkey,
               Orderkey,
               MCompany,
               ExternOrderKey,
               TaskBatchNo,
               LogicalName,
               Shipperkey,
               PLOC,
               ordudef04,
               SKU,
               SDESCR,
               AltSKU,
               PQty,
               ordudef03
      FROM #TEMPPACKLIST43RPT
      ORDER BY orderkey,ExternOrderKey,sku
      
   WHILE @@TRANCOUNT < @n_StartTCnt
   BEGIN
      BEGIN TRAN
   END

END -- procedure


GO