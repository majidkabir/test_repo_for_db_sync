SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store Procedure: isp_DeliveryOrder14                                 */
/* Creation Date: 02-DEC-2022                                           */
/* Copyright: LFL                                                       */
/* Written by: Mingle                                                   */
/*                                                                      */
/* Purpose:  WMS-21227 SG - THG - Outbound Delivery Note [CR]           */
/*                                                                      */
/* Usage:  Used for report dw = r_dw_delivery_Order_14                  */
/*                                                                      */
/* Called By: Exceed                                                    */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author  Ver.  Purposes                                  */
/* 02-12-2022   Mingle  1.0   DevOps Combine Script(Created - WMS-21227)*/
/************************************************************************/

CREATE PROC [dbo].[isp_DeliveryOrder14]
      (@c_MBOLKey NVARCHAR(10))
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_Continue INT = 1

   IF(@n_Continue = 1 OR @n_Continue = 2)
   BEGIN
      SELECT  ISNULL(M.AddWho,'') AS Addwho
             ,M.Mbolkey
             ,ISNULL(M.ArrivalDate,'') AS ArrivalDate
             ,ISNULL(M.DestinationCountry,'') AS DestinationCountry
             ,ISNULL(ST.Company,'') AS Company
             ,ISNULL(ST.Address1,'') AS Address1
             ,ISNULL(ST.Address2,'') AS Address2
             ,ISNULL(ST.Address3,'') AS Address3
             ,ISNULL(ST.Address4,'') AS Address4
             ,PLTD.Palletkey
             ,COUNT(DISTINCT PLTD.Palletkey) AS NoOfPalletkey
             ,COUNT(DISTINCT PLTD.CaseId) AS NoofCase
           --  ,ORD.ORDERKEY
             ,CLR.Description AS Descr
             ,ISNULL(CLR1.SHORT,'') AS ShowDescr
				 ,M.OtherReference	
				 ,M.ExternMbolKey	 
				 ,ISNULL(CLR2.SHORT,'') AS ShowField	
      FROM MBOL M (NOLOCK) 
      JOIN MBOLDETAIL MD (NOLOCK) ON M.MBOLKEY = MD.MBOLKEY
      JOIN ORDERS ORD (NOLOCK) ON ORD.ORDERKEY = MD.ORDERKEY
      JOIN STORER ST (NOLOCK) ON ORD.STORERKEY = ST.STORERKEY
      LEFT JOIN PALLETDETAIL PLTD (NOLOCK) ON PLTD.UserDefine02 = ORD.ORDERKEY
      LEFT JOIN CODELKUP CLR(NOLOCK) ON CLR.Code = M.TransMethod AND CLR.Listname = 'TRANSMETH' 
      LEFT JOIN CODELKUP CLR1(NOLOCK) ON ORD.Storerkey = CLR1.Storerkey AND CLR1.Code = 'ShowDescr' AND CLR1.Listname = 'REPORTCFG' 
                                     AND CLR1.Long = 'r_dw_delivery_Order_14'
		LEFT JOIN CODELKUP CLR2(NOLOCK) ON ORD.Storerkey = CLR2.Storerkey AND CLR2.Code = 'ShowField' AND CLR2.Listname = 'REPORTCFG' 
                                     AND CLR2.Long = 'r_dw_delivery_Order_14'	 
      WHERE M.Mbolkey = @c_MBOLKey
      GROUP BY ISNULL(M.AddWho,'')
              ,M.Mbolkey
              ,ISNULL(M.ArrivalDate,'')
              ,ISNULL(M.DestinationCountry,'')
              ,ISNULL(ST.Company,'')
              ,ISNULL(ST.Address1,'')
              ,ISNULL(ST.Address2,'')
              ,ISNULL(ST.Address3,'')
              ,ISNULL(ST.Address4,'')
              ,PLTD.Palletkey
              --   ,ORD.ORDERKEY
              ,CLR.Description
              ,ISNULL(CLR1.SHORT,'')
				  ,M.OtherReference	  
				  ,M.ExternMbolKey	 
				  ,ISNULL(CLR2.SHORT,'')	
           
   END

END


GO