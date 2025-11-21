SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/******************************************************************************/    
/* Function: fnc_GetOrderQty                                                  */    
/* Creation Date: 04-JUL-2012                                                 */    
/* Copyright: IDS                                                             */    
/* Written by: YTWan                                                          */    
/*                                                                            */    
/* Purpose:                                                                   */    
/*                                                                            */    
/* Input Parameters: MBOLKey                                                  */    
/*                                                                            */    
/* OUTPUT Parameters: Table                                                   */    
/*                                                                            */    
/* Return Status: NONE                                                        */    
/*                                                                            */    
/* Usage:                                                                     */    
/*                                                                            */    
/* Local Variables:                                                           */    
/*                                                                            */    
/* Called By: When Retrieve Records                                           */    
/*                                                                            */    
/* PVCS Version: 1.13                                                         */    
/*                                                                            */    
/* Version: 5.4                                                               */    
/* Data Modifications:                                                        */    
/*                                                                            */    
/* Updates:                                                                   */    
/* Date         Author     Ver   Purposes                                     */    
/******************************************************************************/    

CREATE FUNCTION [dbo].[fnc_GetOrderQty] (@n_cbolkey INT, @c_MBOLKey NVARCHAR(10))  
RETURNS @tOrderQty TABLE   
(   MBOLKey          NVARCHAR(10)  NOT NULL
  , Orderkey         NVARCHAR(10)  NOT NULL  
  , QtyAllocPicked   INT          NULL DEFAULT 0  
  , QtyPacked        INT          NULL DEFAULT 0  
 )  
AS  
BEGIN  
   IF EXISTS(SELECT 1 FROM ORDERDETAIL o WITH (NOLOCK) WHERE o.MBOLKey = @c_MBOLKey 
             AND o.ConsoOrderKey IS NOT NULL AND o.ConsoOrderKey <> '')
   BEGIN      	     	     	
      INSERT @tOrderQty (MBOLKey, Orderkey, QtyAllocPicked, QtyPacked) 
      SELECT M.MBOLKey 
            ,O.Orderkey
            ,QtyAllocPicked = ISNULL(SUM(P.Qty),0)
            ,QtyPacked      = ISNULL(SUM(PD.Qty),0)
      FROM MBOL       M  WITH (NOLOCK) 
      JOIN MBOLDETAIL MD WITH (NOLOCK) ON (M.MBOLKey = MD.MBOLKey) 
      JOIN ORDERS     O  WITH (NOLOCK) ON (MD.OrderKey = O.OrderKey) 
      LEFT JOIN PICKDETAIL P  WITH (NOLOCK) ON (O.OrderKey  = P.OrderKey)
      LEFT JOIN PACKDETAIL PD WITH (NOLOCK) ON (P.PickSlipNo= PD.PickSlipNo) 
                                            AND(P.DropID    = PD.DropID)
      WHERE M.MBOLKey = CASE WHEN RTRIM(@c_MBOLKey) = '' THEN M.MBOLKey ELSE RTRIM(@c_MBOLKey) END
      AND   ISNULL(M.CBOLKey,0) = CASE WHEN @n_CBOLKey = 0 THEN ISNULL(M.CBOLKey,0) ELSE @n_CBOLKey END
      GROUP BY M.MBOLKey
            ,  O.Orderkey
   END
   ELSE
   BEGIN
      INSERT @tOrderQty (MBOLKey, Orderkey, QtyAllocPicked, QtyPacked) 
      SELECT M.MBOLKey
            ,O.Orderkey
            ,QtyAllocPicked = ISNULL((Select SUM(Qty) FROM PICKDETAIL PK WITH (NOLOCK) WHERE PK.Orderkey = O.Orderkey),0)
            ,QtyPacked      = ISNULL(SUM(PD.Qty),0)
      FROM MBOL       M  WITH (NOLOCK) 
      JOIN MBOLDETAIL MD WITH (NOLOCK) ON (M.MBOLKey = MD.MBOLKey)
      JOIN ORDERS     O  WITH (NOLOCK) ON (MD.OrderKey = O.OrderKey)
      LEFT JOIN PACKHEADER PH WITH (NOLOCK) ON (O.Orderkey = PH.Orderkey)
      LEFT JOIN PACKDETAIL PD WITH (NOLOCK) ON (PH.PickSlipNo = PD.PickSlipNo)
      WHERE M.MBOLKey = CASE WHEN RTRIM(@c_MBOLKey) = '' THEN M.MBOLKey ELSE RTRIM(@c_MBOLKey) END
      AND   ISNULL(M.CBOLKey,0) = CASE WHEN @n_CBOLKey = 0 THEN ISNULL(M.CBOLKey,0) ELSE @n_CBOLKey END
      GROUP BY M.MBOLKey
            ,  O.Orderkey 
   END
         	    
   RETURN  
END

GO