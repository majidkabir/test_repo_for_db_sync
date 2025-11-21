SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Trigger: fnc_GetOrder_DropID                                         */
/* Creation Date: 06-APR-2017                                           */
/* Copyright: LF Logistics                                              */
/* Written by: Wan                                                      */
/*                                                                      */
/* Purpose: WMS-1466 - CN & SG Logitech - Packing                       */
/*        :                                                             */
/*                                                                      */
/* Called By:  isp_DropID_GetPackSku                                    */
/*          :  isp_DropID_Insert_Packing                                */
/*          :                                                           */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/************************************************************************/
CREATE FUNCTION [dbo].[fnc_GetOrder_DropID] 
  ( 
     @c_DropID    NVARCHAR(20)
  ,  @c_Storerkey NVARCHAR(15) 
  ,  @c_Sku       NVARCHAR(20)
  ,  @n_QtyPacked INT   
  )
RETURNS NVARCHAR(10)
AS
BEGIN
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   
   DECLARE @c_Orderkey  NVARCHAR(10)   
         , @c_Wavekey   NVARCHAR(10)

   SET @c_Orderkey = '' 

   SELECT TOP 1 @c_Wavekey  = Wavekey
   FROM dbo.fnc_GetWaveOrder_DropID(@c_DropID);  

   WITH 
   PICK_ORD( Orderkey, QtyAllocated )
   AS (  SELECT PD.Orderkey, QtyAllocated = ISNULL(SUM(PD.Qty),0)
         FROM PICKDETAIL PD WITH (NOLOCK)
         JOIN WAVEDETAIL WD WITH (NOLOCK) ON (PD.Orderkey = WD.Orderkey)
         WHERE PD.DropID = @c_DropID
         AND   WD.Wavekey= @c_Wavekey
         AND   PD.Storerkey = @c_Storerkey
         AND   PD.Sku = @c_Sku
         GROUP BY PD.Orderkey 
      )
   ,
   PACK_ORD( Orderkey, QtyPacked)
   AS (  SELECT PH.Orderkey, QtyPacked = ISNULL(SUM(PD.Qty),0)
         FROM PACKHEADER PH WITH (NOLOCK) 
         JOIN PACKDETAIL PD WITH (NOLOCK) ON (PH.PickSlipNo = PD.PickSlipNo)
         JOIN WAVEDETAIL WD WITH (NOLOCK) ON (PH.Orderkey = WD.Orderkey)
         WHERE PD.DropID = @c_DropID
         AND   WD.Wavekey= @c_Wavekey
         AND   PD.Storerkey = @c_Storerkey
         AND   PD.Sku = @c_Sku
         GROUP BY PH.Orderkey 
      )

   SELECT TOP 1 @c_Orderkey = PICK_ORD.Orderkey 
   FROM PICK_ORD
   LEFT JOIN PACK_ORD ON  (PICK_ORD.Orderkey = PACK_ORD.Orderkey)
   WHERE PICK_ORD.QtyAllocated - ISNULL(PACK_ORD.QtyPacked,0) >= @n_QtyPacked 
   ORDER BY PICK_ORD.QtyAllocated - ISNULL(PACK_ORD.QtyPacked,0)

   RETURN  @c_Orderkey  
END 

GO