SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
     
     
/*****************************************************************************/  
/* Store procedure: ispUnmatchPackvsPick                                     */  
/* Copyright      : IDS                                                      */  
/*                                                                           */  
/* Purpose: List unmatch Pack vs Pick records for Republic UK                */  
/*                                                                           */  
/* Modifications log:                                                        */  
/*                                                                           */  
/* Date        Author      Ver   Purposes                                    */  
/* 21-Oct-2011 Leong       1.1   SOS# 227916 - Revise qty check logic        */  
/*****************************************************************************/  
  
CREATE PROC [dbo].[ispUnmatchPackvsPick]  
(    @c_LoadKey  NVarChar(10)  
   , @c_MBOLKey  NVarChar(10) )  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE @c_OrderKey  NVarChar(10)  
         , @c_StorerKey NVarChar(15)  
         , @c_Sku       NVarChar(20)  
         , @c_DropId    NVarChar(18)  
         , @n_PackQty   Int  
         , @n_PickQty   Int  
  
   SET @c_LoadKey = ISNULL(RTRIM(@c_LoadKey), '')  
   SET @c_MBOLKey = ISNULL(RTRIM(@c_MBOLKey), '')  
  
   IF @c_LoadKey = '' AND @c_MBOLKey = ''  
      RETURN  
  
   IF LEN(@c_LoadKey) > 0 AND LEN(@c_MBOLKey) > 0  
      RETURN  
  
   IF OBJECT_ID('tempdB..#PICK') IS NOT NULL  
   BEGIN  
      DROP TABLE #PICK  
   END  
  
   IF OBJECT_ID('tempdB..#PACK') IS NOT NULL  
   BEGIN  
      DROP TABLE #PACK  
   END  
  
   IF OBJECT_ID('tempdB..#RESULT') IS NOT NULL  
   BEGIN  
      DROP TABLE #RESULT  
   END  
  
   CREATE TABLE #PACK (  
        LoadKey      NVarChar(10) NULL  
      , OrderKey     NVarChar(10) NULL  
      , StorerKey    NVarChar(15) NULL  
      , Sku          NVarChar(20) NULL  
      , DropId       NVarChar(18) NULL  
      , PackQty      Int NULL )  
  
   CREATE TABLE #PICK (  
        LoadKey      NVarChar(10) NULL  
      , OrderKey     NVarChar(10) NULL  
      , StorerKey    NVarChar(15) NULL  
      , Sku          NVarChar(20) NULL  
      , DropId       NVarChar(18) NULL  
      , Loc          NVarChar(10) NULL  
      , PickQty      Int NULL )  
  
   CREATE TABLE #RESULT (  
        LoadKey      NVarChar(10) NULL  
      , MBOLKey      NVarChar(10) NULL  
      , OrderKey     NVarChar(10) NULL  
      , StorerKey    NVarChar(15) NULL  
      , Sku          NVarChar(20) NULL  
      , Loc          NVarChar(10) NULL  
      , DropId       NVarChar(18) NULL  
      , PackQty      Int NULL  
      , PickQty      Int NULL )  
  
   -- Get All PackDetail Records  
   INSERT INTO #PACK (LoadKey, OrderKey, StorerKey, Sku, DropId, PackQty)  
   SELECT O.LoadKey, PH.OrderKey, O.StorerKey, PD.Sku, PD.DropId, SUM(PD.Qty) AS Qty  
   FROM PackDetail PD WITH (NOLOCK)  
   JOIN PackHeader PH WITH (NOLOCK) ON PH.PickSlipNo = PD.PickSlipNo  
   JOIN ORDERS O WITH (NOLOCK) ON O.OrderKey = PH.OrderKey  
   WHERE ( O.LoadKey = @c_LoadKey OR @c_LoadKey = '' )  
   AND ( O.MBOLKey = @c_MBOLKey OR @c_MBOLKey = '' )  
   GROUP BY O.LoadKey, PH.OrderKey, O.StorerKey, PD.Sku, PD.DropId  
   ORDER BY O.LoadKey, PH.OrderKey, O.StorerKey, PD.Sku, PD.DropId  
  
   -- Get All PickDetail Records  
   INSERT INTO #PICK (LoadKey, OrderKey, StorerKey, Sku, DropId, Loc, PickQty)  
   SELECT O.LoadKey, PD.OrderKey, O.StorerKey, PD.Sku, PD.DropId  
        , MAX(PD.Loc) AS Loc  
        , SUM(PD.Qty) AS Qty  
   FROM PickDetail PD WITH (NOLOCK)  
   JOIN ORDERS O WITH (NOLOCK) ON O.OrderKey = PD.OrderKey  
   WHERE ( O.LoadKey = @c_LoadKey OR @c_LoadKey = '' )  
   AND ( O.MBOLKey = @c_MBOLKey OR @c_MBOLKey = '' )  
   AND PD.Status >= '5'  
   AND PD.Qty > 0  
   AND NOT ( ISNULL(RTRIM(O.UserDefine01), '') = '' AND ISNULL(RTRIM(PD.CaseId), '') <> '' )  
   GROUP BY O.LoadKey, PD.OrderKey, O.StorerKey, PD.Sku, PD.DropId  
   UNION ALL  
   SELECT O.LoadKey, PD.OrderKey, O.StorerKey, PD.Sku, PD.AltSku  
        , MAX(PD.Loc) AS Loc  
        , SUM(PD.Qty) AS Qty  
   FROM PickDetail PD WITH (NOLOCK)  
   JOIN ORDERS O WITH (NOLOCK) ON O.OrderKey = PD.OrderKey  
   WHERE ( O.LoadKey = @c_LoadKey OR @c_LoadKey = '' )  
   AND ( O.MBOLKey = @c_MBOLKey OR @c_MBOLKey = '' )  
   AND PD.Status >= '3' -- Store Bulk\Case PICK is 3, DropId is PD.AltSku  
   AND PD.Qty > 0  
   AND ISNULL(RTRIM(O.UserDefine01), '') = '' AND ISNULL(RTRIM(PD.CaseId), '') <> ''  
   GROUP BY O.LoadKey, PD.OrderKey, O.StorerKey, PD.Sku, PD.AltSku  
  
   DECLARE CUR_PackDetail CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
      SELECT OrderKey, StorerKey, Sku, DropId, SUM(PickQty)  
      FROM #PICK  
      GROUP BY OrderKey, StorerKey, Sku, DropId  
      ORDER BY OrderKey, StorerKey, Sku, DropId  
  
   OPEN CUR_PackDetail  
   FETCH NEXT FROM CUR_PackDetail INTO @c_OrderKey, @c_StorerKey, @c_Sku, @c_DropId, @n_PickQty  
   WHILE @@FETCH_STATUS <> -1  
   BEGIN  
  
      SET @n_PackQty = 0  
      SELECT @n_PackQty = ISNULL(SUM(PackQty), 0)  
      FROM #PACK WITH (NOLOCK)  
      WHERE OrderKey = @c_OrderKey  
      AND StorerKey = @c_StorerKey  
      AND Sku = @c_Sku  
      AND DropId = @c_DropId  
  
      IF ISNULL(@n_PackQty, 0) <> ISNULL(@n_PickQty, 0)  
      BEGIN  
         INSERT INTO #RESULT ( LoadKey, MBOLKey, OrderKey, StorerKey, Sku  
                             , Loc, DropId, PickQty, PackQty )  
         SELECT ISNULL(RTRIM(@c_LoadKey),'')  
              , ISNULL(RTRIM(@c_MBOLKey),'')  
              , ISNULL(B.OrderKey, A.OrderKey)  
              , ISNULL(B.StorerKey, A.StorerKey)  
              , ISNULL(B.Sku, A.Sku)  
              , ISNULL(A.Loc, '')  
              , ISNULL(B.DropId, A.DropId)  
              , ISNULL(A.PickQty, 0)  
              , ISNULL(B.PackQty, 0)  
         FROM #PICK A  
         FULL OUTER JOIN #PACK B ON A.OrderKey = B.OrderKey AND A.Sku = B.Sku  
                                AND A.DropId = B.DropId  
         WHERE A.OrderKey = @c_OrderKey  
           AND A.Sku = @c_Sku  
           AND A.DropId = @c_DropId  
           AND (A.PickQty IS NULL OR B.PackQty IS NULL OR A.PickQty <> B.PackQty)  
         ORDER BY ISNULL(B.OrderKey, A.OrderKey)  
      END  
  
      FETCH NEXT FROM CUR_PackDetail INTO @c_OrderKey, @c_StorerKey, @c_Sku, @c_DropId, @n_PickQty  
   END  
   CLOSE CUR_PackDetail  
   DEALLOCATE CUR_PackDetail  
  
   SELECT  A.LoadKey  
         , A.MBOLKey  
         , A.OrderKey  
         , A.StorerKey  
         , A.Sku  
         , ISNULL(TD.FromLoc, A.Loc) AS Loc  
         , TD.PickMethod  
         , A.DropId  
         , A.PackQty  
         , A.PickQty  
   FROM #RESULT A WITH (NOLOCK)  
   LEFT JOIN TaskDetail TD WITH (NOLOCK) ON (A.OrderKey = TD.OrderKey AND A.Sku = TD.Sku)  
   ORDER BY A.LoadKey  
          , A.OrderKey  
          , A.StorerKey  
          , A.Sku  
  
   IF OBJECT_ID('tempdB..#PICK') IS NOT NULL  
   BEGIN  
      DROP TABLE #PICK  
   END  
  
   IF OBJECT_ID('tempdB..#PACK') IS NOT NULL  
   BEGIN  
      DROP TABLE #PACK  
   END  
  
   IF OBJECT_ID('tempdB..#RESULT') IS NOT NULL  
   BEGIN  
      DROP TABLE #RESULT  
   END  
END

GO