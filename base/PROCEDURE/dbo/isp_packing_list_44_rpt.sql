SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*************************************************************************/
/* Stored Procedure: isp_Packing_List_44_rpt                             */
/* Creation Date: 2018-05-07                                             */
/* Copyright: IDS                                                        */
/* Written by:                                                           */
/*                                                                       */
/* Purpose: WMS-4900-CN Levis Multi-Order Packing List Report            */
/*                                                                       */
/* Called By: r_Packing_List_44_rpt                                      */
/*                                                                       */
/* PVCS Version: 1.1                                                     */
/*                                                                       */
/* Version: 5.4                                                          */
/*                                                                       */
/* Data Modifications:                                                   */
/*                                                                       */
/* Updates:                                                              */
/* Date         Author  Ver   Purposes                                   */
/*************************************************************************/
CREATE PROC [dbo].[isp_Packing_List_44_rpt]
         (  @c_loadkey    NVARCHAR(10)
         )
         
         
         
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_DEFAULTS OFF  
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE @c_storerkey      NVARCHAR(10)

                   
    
   CREATE TABLE #TMP_PACKLIST44RDT (
          rowid           int identity(1,1),
          Orderkey        NVARCHAR(20)  NULL,
          OHUDF04         NVARCHAR(30)  NULL,
          C_Contact1      NVARCHAR(45)  NULL,
          C_Address1      NVARCHAR(45)  NULL,
          C_Address2      NVARCHAR(45)  NULL,
          C_Address3      NVARCHAR(45)  NULL,
          C_Address4      NVARCHAR(45)  NULL,
          Shipperkey      NVARCHAR(20)  NULL,
          MSKU            NVARCHAR(20)  NULL,
          SDESCR          NVARCHAR(150) NULL,
          SStyle          NVARCHAR(20)  NULL,
          SColor          NVARCHAR(20)  NULL,
          SSize           NVARCHAR(20)  NULL,
          PQty            INT,
          LOC             NVARCHAR(10)  NULL,
          MCompany        NVARCHAR(45) NULL,
          OHAddDate       DATETIME NULL,
          TBatchNo        NVARCHAR(10) NULL,
          DevicePosition  NVARCHAR(10) NULL,
          Loadkey         NVARCHAR(20) NULL)           
   
   
  -- SET @n_NoOfLine = 6
   SET @c_storerkey = ''
   
   SELECT TOP 1 @c_storerkey = OH.Storerkey
   FROM ORDERS OH (NOLOCK)
   WHERE Loadkey = @c_loadkey
   

      INSERT INTO #TMP_PACKLIST44RDT
      (
         -- rowid -- this column value is auto-generated
         Orderkey,
         OHUDF04,
         C_Contact1,
         C_Address1,
         C_Address2,
         C_Address3,
         C_Address4,
         Shipperkey,
         MSKU,
         SDESCR,
         SStyle,
         SColor,
         SSize,
         PQty,
         LOC,
         MCompany,
         OHAddDate,
         TBatchNo,
         DevicePosition,
         Loadkey
      )

      SELECT 
               OH.OrderKey, 
               OH.UserDefine04, 
               OH.C_contact1, 
               OH.C_Address1,
               OH.C_Address2,
               OH.C_Address3,
               OH.C_Address4,
               OH.ShipperKey,
               s.MANUFACTURERSKU, 
               s.DESCR, 
               s.Style,
               s.color,
               s.Size,
               pd.Qty, 
               pd.Loc,
               OH.M_Company, 
               OH.AddDate, 
               pt.TaskBatchNo, 
               pt.DevicePosition,
               OH.LoadKey
               --,(Row_Number() OVER (PARTITION BY OH.LoadKey ORDER BY s.MANUFACTURERSKU Asc)-1)/4 AS recgrp
               FROM Orders OH WITH (NOLOCK)
               JOIN PICKDETAIL PD WITH (NOLOCK) ON OH.StorerKey = pd.Storerkey
                                               AND OH.OrderKey = pd.OrderKey 
               JOIN PackTask PT WITH (NOLOCK) ON pd.OrderKey = pt.Orderkey 
               JOIN SKU S WITH (NOLOCK) ON  pd.Storerkey = s.StorerKey AND pd.sku = s.sku 
               WHERE OH.StorerKey = @c_storerkey 
               AND OH.LoadKey = @c_loadkey
               ORDER BY OH.Orderkey desc

      
  
         
    SELECT
      tp.loadkey,
      tp.Orderkey,
      tp.OHUDF04,
      tp.C_Contact1,
      tp.C_Address1,
      tp.C_Address2,
      tp.C_Address3,
      tp.C_Address4,
      tp.Shipperkey,
      tp.MSKU,
      tp.SStyle,
      tp.SSize,
      tp.SColor,
      tp.PQty,
      tp.SDESCR,
      tp.LOC,
      tp.MCompany,
      tp.OHAddDate,
      tp.TBatchNo,
      tp.DevicePosition
    FROM
      #TMP_PACKLIST44RDT AS tp
    WHERE tp.loadkey = @c_loadkey
    ORDER BY tp.loadkey,tp.Orderkey,MSKU
    
    QUIT_SP:
    
END


GO