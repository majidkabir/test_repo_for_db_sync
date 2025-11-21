SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: isp_PackListBySku15                                     */
/* Creation Date: 08-APR-2020                                           */
/* Copyright: LF Logistics                                              */
/* Written by: CSCHONG                                                  */
/*                                                                      */
/* Purpose: WMS-12604 TH-UA Shipping Packlist for Ecom                  */
/*        :                                                             */
/* Called By: r_dw_packing_list_by_Sku15                                */
/*          :                                                           */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/* 20-MAY-2020 CSCHONG  1.1   WMS-13423 - fix duplicate qty (CS01)      */
/* 27-MAY-2020 CSCHONG  1.1   WMS-13423 - Fix qty issue (CS02)          */
/************************************************************************/
CREATE PROC [dbo].[isp_PackListBySku15]
           @c_PickSlipNo        NVARCHAR(10)
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @c_descr      NVARCHAR(90),
           @c_sku        NVARCHAR(90),
           @c_extprice   FLOAT,
           @c_b_contact1 NVARCHAR(90),
           @c_b_address1 NVARCHAR(90),
           @c_b_address2 NVARCHAR(90),
           @c_b_address3 NVARCHAR(90),
           @c_b_address4 NVARCHAR(90),
           @c_c_contact1 NVARCHAR(90),
           @c_c_address1 NVARCHAR(90),
           @c_c_address2 NVARCHAR(90),
           @c_c_address3 NVARCHAR(90),
           @c_c_address4 NVARCHAR(90),
           @c_c_city     NVARCHAR(90),
           @c_userdef05  NVARCHAR(30),
           @c_qty        INT,
           @c_showField  NVARCHAR(1),
           @c_ExtOrdKey  NVARCHAR(50)   


   SET @c_descr = ''
   SET @c_sku = ''
   SET @c_extprice = 0.00

   CREATE TABLE #PLISTBYSKU15(
    B_Contact1       NVARCHAR(60)
   ,B_Address1       NVARCHAR(90)
   ,B_Address2       NVARCHAR(90)
   ,B_Address3       NVARCHAR(90)
   ,B_Address4       NVARCHAR(90)
   ,C_Contact1       NVARCHAR(60)
   ,C_Address1       NVARCHAR(90)
   ,C_Address2       NVARCHAR(90)
   ,C_Address3       NVARCHAR(90)
   ,C_Address4       NVARCHAR(90)
   ,C_City           NVARCHAR(90)
   ,Descr            NVARCHAR(90)
   ,Qty              INT
   ,ExtPrice         FLOAT
   ,UserDefine05     NVARCHAR(30)
   ,PickSlipNo       NVARCHAR(10)
   ,SKU              NVARCHAR(50)
   ,ShowField        NVARCHAR(1)
   ,ExtOrdKey        NVARCHAR(50) )       

   CREATE TABLE #PLISTBYSKU15_Final(
    B_Contact1        NVARCHAR(60)
   ,B_Address1       NVARCHAR(90)
   ,B_Address2       NVARCHAR(90)
   ,B_Address3       NVARCHAR(90)
   ,B_Address4       NVARCHAR(90)
   ,C_Contact1       NVARCHAR(60)
   ,C_Address1       NVARCHAR(90)
   ,C_Address2       NVARCHAR(90)
   ,C_Address3       NVARCHAR(90)
   ,C_Address4       NVARCHAR(90)
   ,C_City           NVARCHAR(90)
   ,Descr            NVARCHAR(90)
   ,Qty              INT
   ,ExtPrice         FLOAT
   ,UserDefine05     NVARCHAR(30)
   ,ShowField        NVARCHAR(1)
   ,ExtOrdKey        NVARCHAR(50))       
   

   INSERT INTO #PLISTBYSKU15(B_Contact1,B_Address1,B_Address2,B_Address3,B_Address4,C_Contact1,C_Address1,C_Address2,C_Address3,C_Address4
                            ,C_City, Descr, Qty,ExtPrice,UserDefine05,PickSlipNo,SKU,ShowField,ExtOrdKey)           
   SELECT ISNULL(O.B_contact1,'')
         ,ISNULL(O.B_Address1,'')
         ,ISNULL(O.B_Address2,'')
         ,ISNULL(O.B_Address3,'')
         ,ISNULL(O.B_Address4,'')
         ,ISNULL(O.C_contact1,'')
         ,ISNULL(O.C_Address1,'')
         ,ISNULL(O.C_Address2,'')
         ,ISNULL(O.C_Address3,'')
         ,ISNULL(O.C_Address4,'')
         ,ISNULL(O.C_City,'')
         ,LTRIM(RTRIM(S.DESCR))
         ,(PID.QTY)                            --CS01
         ,OD.ExtendedPrice
         ,ISNULL(OD.USERDEFINE05,'')
         ,PH.PickSlipNo
        -- ,S.SKU                              --CS01
         , ''                                  --CS01
         ,ISNULL(CLR.short,'N') as ShowField  
         ,O.ExternOrderkey          
   FROM ORDERS     O  WITH (NOLOCK)
   JOIN ORDERDETAIL OD WITH (NOLOCK) ON OD.OrderKey=O.OrderKey
   JOIN PACKHEADER PH WITH (NOLOCK) ON (O.Orderkey = PH.Orderkey AND O.Storerkey = PH.Storerkey)
  -- JOIN PACKDETAIL PD WITH (NOLOCK) ON (PD.PickSlipNo = PH.PickSlipNo and PD.SKU = OD.SKU)        --CS02 START
   
    JOIN PICKDETAIL PID WITH (NOLOCK) ON (OD.Orderkey    = PID.Orderkey      
                                     AND PID.OrderLineNumber = OD.OrderLineNumber)  
   JOIN SKU         S WITH (NOLOCK) ON (S.Storerkey = PID.Storerkey)
                                    AND(S.Sku = PID.Sku)                                           --CS02 END
   LEFT OUTER JOIN Codelkup CLR (NOLOCK) ON (o.Storerkey = CLR.Storerkey AND CLR.Code = 'SHOWFIELD'  
                AND CLR.Listname = 'REPORTCFG' AND CLR.Long = 'r_dw_packing_list_by_Sku15' AND ISNULL(CLR.Short,'') <> 'N'
                AND CLR.code2 = UPPER(O.shipperkey)) 
   WHERE  PH.PickSlipNo = @c_PickSlipNo AND O.OrderGroup = 'ECOM'
   --GROUP BY  ISNULL(O.B_contact1,'')                                                                --CS02 START
   --      ,ISNULL(O.B_Address1,'')
   --      ,ISNULL(O.B_Address2,'')
   --      ,ISNULL(O.B_Address3,'')
   --      ,ISNULL(O.B_Address4,'')
   --      ,ISNULL(O.C_contact1,'')
   --      ,ISNULL(O.C_Address1,'')
   --      ,ISNULL(O.C_Address2,'')
   --      ,ISNULL(O.C_Address3,'')
   --      ,ISNULL(O.C_Address4,'')
   --      ,ISNULL(O.C_City,'')
   --      ,LTRIM(RTRIM(S.DESCR))
   --      ,OD.ExtendedPrice
   --      ,OD.USERDEFINE05
   --      ,PH.PickSlipNo
   --   --   ,S.SKU                                   --CS01
   --      ,ISNULL(CLR.short,'N') 
   --      ,O.ExternOrderkey
   --      ,(PID.QTY)                                 --CS01                           --CS02 END
--CS01 START
/*
   DECLARE CUR_QTY CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
   SELECT DISTINCT B_Contact1
   ,B_Address1
   ,B_Address2
   ,B_Address3
   ,B_Address4
   ,C_Contact1
   ,C_Address1
   ,C_Address2
   ,C_Address3
   ,C_Address4
   ,C_City
   ,Descr
   ,Qty
   ,ExtPrice
   ,UserDefine05
   ,ShowField      
   ,ExtOrdkey                   
   FROM #PLISTBYSKU15

   OPEN CUR_QTY

   FETCH NEXT FROM CUR_QTY INTO  @c_B_Contact1,@c_B_Address1,@c_B_Address2,@c_B_Address3,@c_B_Address4,@c_C_Contact1,@c_C_Address1,
                                 @c_C_Address2,@c_C_Address3,@c_C_Address4,@c_C_City, @c_Descr,@c_qty,@c_extprice,@c_userdef05,
                                 @c_showField,@c_ExtOrdKey   
   WHILE @@FETCH_STATUS <> -1
   BEGIN
   SELECT DISTINCT @c_descr    = DESCR,
                   @c_qty      = SUM(QTY),
                   @c_extprice = SUM(EXTPRICE)
   FROM #PLISTBYSKU15 WHERE DESCR = @c_descr
   GROUP BY DESCR

   INSERT INTO #PLISTBYSKU15_Final(B_Contact1,B_Address1,B_Address2,B_Address3,B_Address4,C_Contact1,C_Address1,C_Address2,
                                   C_Address3,C_Address4,C_City, Descr, Qty,ExtPrice,UserDefine05,ShowField,ExtOrdKey)                   
   VALUES(@c_B_Contact1,@c_B_Address1,@c_B_Address2,@c_B_Address3,@c_B_Address4,@c_C_Contact1,@c_C_Address1,
          @c_C_Address2,@c_C_Address3,@c_C_Address4,@c_C_City, @c_Descr,@c_qty,@c_extprice,@c_userdef05,@c_showField,@c_ExtOrdKey) 

   FETCH NEXT FROM CUR_QTY INTO @c_B_Contact1,@c_B_Address1,@c_B_Address2,@c_B_Address3,@c_B_Address4,@c_C_Contact1,@c_C_Address1,
                                @c_C_Address2,@c_C_Address3,@c_C_Address4,@c_C_City, @c_Descr,@c_qty,@c_extprice,@c_userdef05,
                                @c_showField,@c_ExtOrdKey
   END
   CLOSE CUR_QTY
   DEALLOCATE CUR_QTY
 */
--CS01 End
   SELECT B_Contact1
   ,B_Address1
   ,B_Address2
   ,B_Address3
   ,B_Address4
   ,C_Contact1
   ,C_Address1
   ,C_Address2
   ,C_Address3
   ,C_Address4
   ,C_City
   ,Descr
   ,Qty
   ,ExtPrice
   ,UserDefine05 
   ,showfield    
   ,ExtOrdKey
   from #PLISTBYSKU15           --CS01
   --GROUP BY B_Contact1
   --,B_Address1
   --,B_Address2
   --,B_Address3
   --,B_Address4
   --,C_Contact1
   --,C_Address1
   --,C_Address2
   --,C_Address3
   --,C_Address4
   --,C_City
   --,Descr
   --,ExtPrice
   --,UserDefine05
   --,ShowField           
   --,ExtOrdKey


END -- procedure


GO