SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: isp_PackListByCtn14                                     */
/* Creation Date: 08-NOV-2018                                           */
/* Copyright: LF Logistics                                              */
/* Written by: CSCHONG                                                  */
/*                                                                      */
/* Purpose:  WMS-6807 D1MPackingList                                    */
/*        :                                                             */
/* Called By: r_dw_packing_list_by_ctn14                                */
/*          :                                                           */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author       Ver Purposes                               */
/* 8-11-2018    Joseph Yu    WMS-6807 D1MPackingList                    */
/* 07-12-2018   Leong        INC0499752 - Revise Left Join PackSerialNo.*/
/* 09-04-2021   CSCHONG      WMS-16024 PB-Standardize TrackingNo (CS01)*/
/************************************************************************/

CREATE PROC [dbo].[isp_PackListByCtn14]
   @c_PickSlipNo NVARCHAR(10),
   @c_Orderkey   NVARCHAR(10) = ''
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE
        @n_StartTCnt             INT
      , @n_Continue              INT
      , @n_PrintOrderAddresses   INT
      , @n_Temp                  NVARCHAR(4000)

   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_Continue = 1
   SET @n_Temp = ''

   SELECT
        --ISNULL(ORD.UserDefine04,'') AS OHUDF04   --CS01
        ISNULL(ORD.TrackingNo,'') AS OHUDF04       --CS01
      , ISNULL(ORD.OrderDate,'') AS ORDERDATE
      , ISNULL(RTRIM(ORD.C_ADDRESS1),'') + ' ' + ISNULL(RTRIM(ORD.C_ADDRESS2),'') + ' ' +
        ISNULL(RTRIM(ORD.C_ADDRESS3),'') + ' '+ ISNULL(RTRIM(ORD.C_ADDRESS4),'') AS C_ADDRESS
      , ISNULL(ORD.C_contact1,'') AS C_CONTACT1
      , ISNULL(ORD.C_Phone1,'') AS C_PHONE1
      , ISNULL(ORD.ExternOrderKey,'') AS EXTERNORDERKEY
      , ISNULL(CLKUP.Short,'') AS CLKUP_SHORT
      , ISNULL(S.BUSR10,'') AS BUSR10
      , ISNULL(S.BUSR2,'') AS BUSR2
      , ISNULL(PS.SerialNo,'') AS SerialNo
      , ISNULL(S.Descr,'') AS DESCR
      , CASE WHEN ISNULL(PS.SerialNo,'') = '' THEN PD.QTY ELSE 1 END AS QTY
      , ISNULL(ORD.Notes,'') AS ORDERNOTES
      , COUNT(PD.LabelLine) AS CNTLabelLine
      , ISNULL(S.Color,'') AS SColor
      , ISNULL(S.Size,'') AS SSize
      , ISNULL(ORD.Salesman,'') AS Salesman
      , ( ISNULL(RTRIM(ORDT.UserDefine01),'') + ISNULL(RTRIM(ORDT.UserDefine02),'') ) AS ODUDF01
      , ORDT.UnitPrice AS UnitPrice
      , CASE WHEN ISNULL(PS.SerialNo,'') = '' THEN (PD.Qty * ORDT.UnitPrice) ELSE ORDT.UnitPrice END AS PRICE
      , ISNULL(S.BUSR3,'') AS BUSR3
   FROM ORDERS ORD WITH (NOLOCK)
   JOIN PACKHEADER PH WITH (NOLOCK) ON (PH.OrderKey = ORD.OrderKey)
   JOIN CODELKUP CLKUP WITH (NOLOCK) ON CLKUP.listname ='D1MPlat'  AND CLKUP.code = ORD.salesman
                AND (CLKUP.Storerkey = ORD.StorerKey)
   JOIN PACKDETAIL PD WITH (NOLOCK) ON (PH.PickSlipNo = PD.PickSlipNo)
   JOIN SKU S WITH (NOLOCK) ON (PD.Sku = S.Sku AND PD.StorerKey = S.StorerKey)
   LEFT JOIN PACKSERIALNO PS WITH (NOLOCK) ON (PS.PickSlipNo = PD.PickSlipNo) AND (PS.LabelNo = PD.LabelNo) AND (PS.LabelLine = PD.LabelLine) -- INC0499752
   JOIN ORDERDETAIL ORDT WITH (NOLOCK) ON (ORD.Orderkey = ORDT.OrderKey AND ORDT.Sku = PD.Sku AND ORDT.StorerKey = PD.StorerKey)
   WHERE PH.Pickslipno = @c_PickSlipNo
   GROUP BY ISNULL(ORD.ExternOrderKey,'')
        --  , ISNULL(ORD.UserDefine04,'')
          , ISNULL(ORD.TrackingNo,'')   --CS01
          , ISNULL(ORD.OrderDate,'')
          , ISNULL(CLKUP.Short,'')
          , ISNULL(ORD.C_contact1,'')
          , ISNULL(RTRIM(ORD.C_ADDRESS1),'') + ' ' + ISNULL(RTRIM(ORD.C_ADDRESS2),'') + ' ' +
            ISNULL(RTRIM(ORD.C_ADDRESS3),'') + ' '+ ISNULL(RTRIM(ORD.C_ADDRESS4),'')
          , ISNULL(ORD.C_Phone1,'')
          , ISNULL(S.BUSR10,'')
          , ISNULL(PS.SerialNo,'')
          , ISNULL(ORD.Notes,'')
          , ISNULL(S.Descr,'')
          , ISNULL(S.Color,'')
          , ISNULL(S.Size,'')
          , ISNULL(ORD.Salesman,'')
          , ISNULL(S.BUSR2,'')
          , ( ISNULL(RTRIM(ORDT.UserDefine01),'') + ISNULL(RTRIM(ORDT.UserDefine02),'') )
          , ORDT.UnitPrice
          , ISNULL(S.Busr3,'')
          , PD.Qty
   ORDER BY ISNULL(ORD.ExternOrderKey,'')

QUIT_SP:
END -- procedure

GO