SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/    
/* Stored Procedure: isp_commercialinvoice_07                           */    
/* Creation Date: 26-SEP-2019                                           */    
/* Copyright: IDS                                                       */    
/* Written by: CSCHONG                                                  */    
/*                                                                      */    
/* Purpose:   WMS-10263 -  SG - THG - Commercial Invoice                */    
/*                                                                      */    
/*                                                                      */    
/* Called By: report dw = r_dw_commercialinvoice_07                     */    
/*                                                                      */    
/* PVCS Version: 1.1                                                    */    
/*                                                                      */    
/* Version: 5.4                                                         */    
/*                                                                      */    
/* Data Modifications:                                                  */    
/*                                                                      */    
/* Updates:                                                             */    
/* Date         Author    Ver.  Purposes                                */   
/* 07-OCT-2021  CSCHONG   1.0   Devops scripts combine                  */ 
/************************************************************************/    
    
CREATE PROC [dbo].[isp_commercialinvoice_07] (    
   @c_MBOLKey NVARCHAR(21)     
)     
AS     
BEGIN    
   SET NOCOUNT ON    
  -- SET ANSI_WARNINGS OFF    
   SET QUOTED_IDENTIFIER OFF    
   SET ANSI_NULLS OFF    
   SET ANSI_DEFAULTS OFF    

   DECLARE @n_continue INT

   SET @n_continue = 1

   IF(@n_continue = 1 OR @n_continue = 2)
   BEGIN
      SELECT  MD.Mbolkey as mbolkey
                  ,ORD.TrackingNo as TrackingNo 
                  ,LTRIM(RTRIM(ISNULL(ORD.C_Country,''))) as C_Country
                  ,PH.TTLCNTS as TTLCNTS
                  ,LTRIM(RTRIM(ISNULL(PH.CtnTyp1,''))) as CtnTyp1
                  ,CASE WHEN sku.busr8='gram' THEN (sku.grosswgt/1000) * PAD.Qty ELSE sku.grosswgt END as netwgt
                  ,LTRIM(RTRIM(PID.Sku))  as SKU 
                  ,LTRIM(RTRIM(SKU.DESCR)) as descr
                  ,PAD.Qty      as qty
                  ,ISNULL(ORDET.UnitPrice,0.00) as unitprice
                  ,ISNULL(CZ.CartonLength,0.00)  as CtnLength
                  ,ISNULL(CZ.CartonWidth,0.00)   as CtnWidth
                  ,ISNULL(CZ.CartonHeight,0.00)  as CtnHeight
                  ,CASE WHEN ISNUMERIC(CZ.Barcode) = 1 THEN CAST(ISNULL(CZ.Barcode,'') as float) ELSE 0.00 END as GWGT
                  ,ISNULL(C.UDF01,'') as Shipper
                  ,ISNULL(C.UDF02,'') as Consignee
                  ,ISNULL(C.UDF03,'') as ShipMethod
      FROM MBOLDETAIL MD (NOLOCK)
      JOIN ORDERS ORD (NOLOCK) ON MD.ORDERKEY = ORD.ORDERKEY
      JOIN ORDERDETAIL ORDET (NOLOCK) ON ORDET.ORDERKEY = ORD.ORDERKEY
      JOIN STORER ST (NOLOCK) ON ST.STORERKEY = ORD.STORERKEY
      JOIN PICKDETAIL PID (NOLOCK) ON PID.ORDERKEY = ORDET.ORDERKEY AND PID.OrderLineNumber = ORDET.OrderLineNumber
                              AND PID.Sku = ORDET.Sku
      JOIN SKU (NOLOCK) ON SKU.SKU = ORDET.SKU AND ORD.StorerKey = SKU.StorerKey
      JOIN PACKHEADER PH (NOLOCK) ON PH.Orderkey = ORD.Orderkey AND PH.Storerkey = ORD.Storerkey
      JOIN PACKDETAIL PAD (NOLOCK) ON PAD.Pickslipno = PH.Pickslipno
      LEFT JOIN CARTONIZATION CZ WITH (NOLOCK) ON CZ.cartonizationgroup = PH.CartonGroup AND CZ.CartonType=PH.CtnTyp1
      LEFT JOIN CODELKUP C WITH (NOLOCK) ON C.listname = 'CNCTCODE' AND C.Storerkey = ORD.Storerkey
                                         AND C.Code = 'CNCTMINVO'
      WHERE MD.MbolKey = @c_MBOLKey
      GROUP BY MD.Mbolkey
                  ,ORD.TrackingNo
                  ,PH.TTLCNTS
                  ,LTRIM(RTRIM(ISNULL(ORD.C_Country,'')))
                  ,PH.TTLCNTS
                  ,LTRIM(RTRIM(ISNULL(PH.CtnTyp1,'')))
                  ,CASE WHEN sku.busr8='gram' THEN (sku.grosswgt/1000) * PAD.Qty ELSE sku.grosswgt END
                  ,LTRIM(RTRIM(PID.Sku))
                  ,LTRIM(RTRIM(SKU.DESCR))
                  ,PAD.Qty 
                  ,ISNULL(ORDET.UnitPrice,0.00)
                  ,ISNULL(CZ.CartonLength,0.00)  
                  ,ISNULL(CZ.CartonWidth,0.00)  
                  ,ISNULL(CZ.CartonHeight,0.00) 
                  ,CASE WHEN ISNUMERIC(CZ.Barcode) = 1 THEN CAST(ISNULL(CZ.Barcode,'') as float) ELSE 0.00 END 
                  ,ISNULL(C.UDF01,'') 
                  ,ISNULL(C.UDF02,'') 
                  ,ISNULL(C.UDF03,'') 
            ORDER BY  MD.Mbolkey , LTRIM(RTRIM(ISNULL(ORD.C_Country,''))),ORD.TrackingNo,LTRIM(RTRIM(PID.Sku))
   END

QUIT:    
END    


GO