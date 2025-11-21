SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: isp_GetLaneAssignInfor                             */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose:                                                             */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Ver.  Author     Purposes                               */
/* 14-01-2010   1.0   Shong      Create                                 */
/* 17-03-2010   1.1   ChewKP     Add in Loose QTY (ChewKP01)            */
/* 10-11-2011   1.2   NJOW01     229328 - Cater for mbol                */ 
/* 28-Jan-2019  1.3   TLTING_ext enlarge externorderkey field length    */  
/* 19-Oct-2019  1.4   WLChooi    WMS-11096 - Add indicator, to see if   */ 
/*                               multiple loadkeys are assigned to 1    */
/*                               lane loc (WL01)                        */
/************************************************************************/
CREATE PROC [dbo].[isp_GetLaneAssignInfor]  
  @c_Loc       NVARCHAR(10)
AS
BEGIN
   DECLARE 
   @c_LoadKey      NVARCHAR(10),
   @c_ID           NVARCHAR(18),
   @n_Qty          INT, 
   @n_NoOfLoad     INT,
   @n_NoofOrders   INT,
   @d_DeliveryDate DATETIME, 
   @n_NoOfConsignee INT, 
   @c_LoadString    NVARCHAR(125),
   @n_Cartons       INT,
   @n_Pallets       INT,
   @n_TotCartons    INT,
   @n_TotPallets    INT
   
   ,@n_LooseQty        INT   -- (ChewKP01)
   ,@n_TotalLooseQTY   INT   -- (ChewKP01)
   
   SELECT @n_NoOfLoad      = COUNT(DISTINCT lpld.LoadKey), 
          @n_NoOfOrders    = COUNT(DISTINCT lpld.ExternOrderKey), 
          @n_NoOfConsignee = COUNT(DISTINCT lpld.ConsigneeKey), 
          @d_DeliveryDate  = MIN(o.DeliveryDate)     
   FROM   LoadPlanLaneDetail lpld WITH (NOLOCK) 
   JOIN   ORDERS o WITH (NOLOCK) 
          ON o.LoadKey = lpld.LoadKey 
          AND o.ExternOrderKey = lpld.ExternOrderKey 
          AND o.ConsigneeKey = lpld.ConsigneeKey
          AND ISNULL(lpld.Loadkey,'') <> '' --NJOW01 
   WHERE  LOC = @c_Loc 
   AND    lpld.Status < '9'
   
   --NJOW01 Start
   DECLARE  
   @n_NoOfMBOL     INT,
   @n_NoofOrders_mb   INT,
   @d_DeliveryDate_mb DATETIME, 
   @n_NoOfConsignee_mb INT, 
   @c_MbolKey NVARCHAR(10)
   
   SELECT @n_NoOfMBOL      = COUNT(DISTINCT lpld.Mbolkey), 
          @n_NoOfOrders_mb    = COUNT(DISTINCT lpld.ExternOrderKey), 
          @n_NoOfConsignee_mb = COUNT(DISTINCT lpld.ConsigneeKey), 
          @d_DeliveryDate_mb  = MIN(o.DeliveryDate)     
   FROM   LoadPlanLaneDetail lpld WITH (NOLOCK) 
   JOIN   ORDERS o WITH (NOLOCK) 
          ON o.Mbolkey = lpld.MbolKey 
          AND o.ExternOrderKey = lpld.ExternOrderKey 
          AND o.ConsigneeKey = lpld.ConsigneeKey
          AND ISNULL(lpld.Mbolkey,'') <> '' 
   WHERE  LOC = @c_Loc 
   AND    lpld.Status < '9'
   
   SET @n_NoOfLoad = @n_NoOfLoad + @n_NoOfMBOL
   SET @n_NoOfOrders = @n_NoOfOrders + @n_NoOfOrders_mb 
   SET @n_NoOfConsignee = @n_NoOfConsignee + @n_NoOfConsignee_mb 
   IF @d_DeliveryDate = NULL
      SET @d_DeliveryDate = @d_DeliveryDate_mb
   --NJOW01 End   
       
   SET @c_LoadString = ''
       
   DECLARE C_LOAD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT DISTINCT lpld.LoadKey  
   FROM   LoadPlanLaneDetail lpld WITH (NOLOCK) 
   JOIN   ORDERS o WITH (NOLOCK) 
          ON o.LoadKey = lpld.LoadKey 
          AND o.ExternOrderKey = lpld.ExternOrderKey 
          AND o.ConsigneeKey = lpld.ConsigneeKey
          AND ISNULL(lpld.LoadKey,'') <> '' --NJOW01
   WHERE  LOC = @c_Loc 
   AND    lpld.Status < '9'
   ORDER BY 1 

   OPEN C_LOAD 
       
   FETCH NEXT FROM C_LOAD INTO @c_LoadKey
   
   WHILE @@FETCH_STATUS <> -1
   BEGIN
      IF LEN(@c_LoadString) = 0
         SET @c_LoadString = @c_LoadKey 
      ELSE
         SET @c_LoadString = @c_LoadString + '/' + @c_LoadKey
         
      FETCH NEXT FROM C_LOAD INTO @c_LoadKey
   END   
   CLOSE C_LOAD
   DEALLOCATE C_LOAD
   
   --NJOW01 Start
   DECLARE C_MBOL CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT DISTINCT lpld.MbolKey  
   FROM   LoadPlanLaneDetail lpld WITH (NOLOCK) 
   JOIN   ORDERS o WITH (NOLOCK) 
          ON o.MbolKey = lpld.MbolKey 
          AND o.ExternOrderKey = lpld.ExternOrderKey 
          AND o.ConsigneeKey = lpld.ConsigneeKey
          AND ISNULL(lpld.MbolKey,'') <> '' 
   WHERE  LOC = @c_Loc 
   AND    lpld.Status < '9'
   ORDER BY 1 

   OPEN C_MBOL 
       
   FETCH NEXT FROM C_MBOL INTO @c_MbolKey
   
   WHILE @@FETCH_STATUS <> -1
   BEGIN
      IF LEN(@c_LoadString) = 0
         SET @c_LoadString = 'MB'+@c_MbolKey 
      ELSE
         SET @c_LoadString = @c_LoadString + '/' + 'MB'+@c_MbolKey
         
      FETCH NEXT FROM C_MBOL INTO @c_MbolKey
   END   
   CLOSE C_MBOL
   DEALLOCATE C_MBOL
   --NJOW01 End   
   
   -- Get Estimated Carton/Pallet
   DECLARE @c_ExternOrderKey NVARCHAR(50),   --tlting_ext
           @c_ConsigneeKey   NVARCHAR(15)
   
   SET @n_TotCartons = 0
   SET @n_TotPallets = 0
   SET @n_TotalLooseQTY = 0 -- (ChewKP01)
           
   DECLARE CUR_CAL_PltCase CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT lpld.LoadKey, lpld.ExternOrderKey, o.ConsigneeKey    
      FROM   LoadPlanLaneDetail lpld WITH (NOLOCK) 
      JOIN   ORDERS o WITH (NOLOCK) 
             ON o.LoadKey = lpld.LoadKey 
             AND o.ExternOrderKey = lpld.ExternOrderKey 
             AND o.ConsigneeKey = lpld.ConsigneeKey
             AND ISNULL(lpld.LoadKey ,'') <> '' --NJOW01
      WHERE  LOC = @c_Loc 
      AND    lpld.Status < '9'
   
   OPEN CUR_CAL_PltCase
   
   FETCH NEXT FROM CUR_CAL_PltCase INTO @c_LoadKey, @c_ExternOrderKey, @c_ConsigneeKey   
   
   WHILE @@FETCH_STATUS <> -1
   BEGIN
      EXEC isp_GetPPKPltCase
         @c_loadkey = @c_LoadKey,
         @c_externorderkey = @c_ExternOrderKey,
         @c_consigneekey = @c_ConsigneeKey,
         @n_totalcarton = @n_Cartons OUTPUT,
         @n_totalpallet = @n_Pallets OUTPUT,
         @n_totalloose=@n_LooseQty OUTPUT   -- (ChewKP01)
      
      SET @n_TotCartons = @n_TotCartons + @n_Cartons
      SET @n_TotPallets = @n_TotPallets + @n_Pallets
      SET @n_TotalLooseQTY = @n_TotalLooseQTY + @n_LooseQty -- (ChewKP01)    
      
      
      FETCH NEXT FROM CUR_CAL_PltCase INTO @c_LoadKey, @c_ExternOrderKey, @c_ConsigneeKey
   END
   CLOSE CUR_CAL_PltCase
   DEALLOCATE CUR_CAL_PltCase

   --NJOW01 Start
   DECLARE CUR_CAL_PltCase_MBOL CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT lpld.MBOLKey, lpld.ExternOrderKey, o.ConsigneeKey    
      FROM   LoadPlanLaneDetail lpld WITH (NOLOCK) 
      JOIN   ORDERS o WITH (NOLOCK) 
             ON o.MbolKey = lpld.MbolKey 
             AND o.ExternOrderKey = lpld.ExternOrderKey 
             AND o.ConsigneeKey = lpld.ConsigneeKey
             AND ISNULL(lpld.MbolKey ,'') <> '' 
      WHERE  LOC = @c_Loc 
      AND    lpld.Status < '9'
   
   OPEN CUR_CAL_PltCase_MBOL
   
   FETCH NEXT FROM CUR_CAL_PltCase_MBOL INTO @c_MbolKey, @c_ExternOrderKey, @c_ConsigneeKey   
   
   WHILE @@FETCH_STATUS <> -1
   BEGIN
      EXEC isp_GetPPKPltCase_MBOL
         @c_Mbolkey = @c_MbolKey,
         @c_externorderkey = @c_ExternOrderKey,
         @c_consigneekey = @c_ConsigneeKey,
         @n_totalcarton = @n_Cartons OUTPUT,
         @n_totalpallet = @n_Pallets OUTPUT,
         @n_totalloose=@n_LooseQty OUTPUT   -- (ChewKP01)
      
      SET @n_TotCartons = @n_TotCartons + @n_Cartons
      SET @n_TotPallets = @n_TotPallets + @n_Pallets
      SET @n_TotalLooseQTY = @n_TotalLooseQTY + @n_LooseQty -- (ChewKP01)    
      
      
      FETCH NEXT FROM CUR_CAL_PltCase_MBOL INTO @c_MbolKey, @c_ExternOrderKey, @c_ConsigneeKey
   END
   CLOSE CUR_CAL_PltCase_MBOL
   DEALLOCATE CUR_CAL_PltCase_MBOL
   --NJOW01 End      
   
   SELECT @c_LoadString, @n_NoofOrders, @n_NoOfConsignee, @d_DeliveryDate, @n_TotCartons, @n_TotPallets ,@n_TotalLooseQTY
        , CASE WHEN CHARINDEX('/',@c_LoadString) > 0 THEN 'MULTIPLE' ELSE @c_Loc END --WL01

END

GO