SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/***************************************************************************/
/* Store Procedure: isp_ABC_Dashboard                                      */
/* Creation Date: 05-JUNE2013                                              */
/* Copyright: LF                                                           */
/* Written by: YTWan                                                       */
/*                                                                         */
/* Purpose:  SOS#271282 LOC ABC Dashboard                                  */
/*                                                                         */
/* Called By:                                                              */
/*                                                                         */
/* PVCS Version: 1.0                                                       */
/*                                                                         */
/* Version: 5.4                                                            */
/*                                                                         */
/* Data Modifications:                                                     */
/*                                                                         */
/* Updates:                                                                */
/* Date         Author    Ver.  Purposes                                   */
/***************************************************************************/
CREATE PROC [dbo].[isp_ABC_Dashboard]
         @c_Facility             NVARCHAR(5)
       , @c_StorerKey            NVARCHAR(10)
       , @c_SkuGroup             NVARCHAR(10)
       , @c_ItemClass            NVARCHAR(10)
       , @c_Susr3                NVARCHAR(18)
       , @c_Busr1                NVARCHAR(30)
       , @c_Class                NVARCHAR(10)
       , @c_Busr5                NVARCHAR(30)
       , @c_AreaKey              NVARCHAR(10)
       , @c_PutawayZone          NVARCHAR(10)
       , @c_PickZone             NVARCHAR(10)
       , @c_LocAisle             NVARCHAR(10)

AS
BEGIN 
   SET NOCOUNT ON      
   SET ANSI_NULLS OFF      
   SET QUOTED_IDENTIFIER OFF      
   SET CONCAT_NULL_YIELDS_NULL OFF  

   CREATE TABLE #TMP_LOCABC 
         (
           Type               NVARCHAR(10)
         , SkuDescr           NVARCHAR(30)
         , StorerKey          NVARCHAR(10)
         , SkuGroup           NVARCHAR(10)
         , ItemClass          NVARCHAR(10)
         , Susr3              NVARCHAR(18)
         , Busr1              NVARCHAR(30)
         , Class              NVARCHAR(10)
         , Busr5              NVARCHAR(30)
         , LocDescr           NVARCHAR(30)
         , Facility           NVARCHAR(5)
         , AreaKey            NVARCHAR(10)
         , PutawayZone        NVARCHAR(10)
         , PickZone           NVARCHAR(10)
         , LocAisle           NVARCHAR(10)
         )
         

   INSERT INTO #TMP_LOCABC (Type, SkuDescr, StorerKey, SkuGroup, ItemClass, Susr3, Busr1, Class, Busr5
                                , LocDescr, Facility, AreaKey, PutawayZone, PickZone, LocAisle)
   VALUES ( 'ALL', 'Product Analysis',  @c_StorerKey, @c_SkuGroup, @c_ItemClass, @c_Susr3, @c_Busr1, @c_Class, @c_Busr5
                 , 'Location Analysis', @c_Facility, @c_AreaKey, @c_PutawayZone, @c_PickZone, @c_LocAisle )

   INSERT INTO #TMP_LOCABC (Type, SkuDescr, StorerKey, SkuGroup, ItemClass, Susr3, Busr1, Class, Busr5
                                , LocDescr, Facility, AreaKey, PutawayZone, PickZone, LocAisle)
   VALUES ( 'EA', 'Piece Pick Analysis', @c_StorerKey, @c_SkuGroup, @c_ItemClass, @c_Susr3, @c_Busr1, @c_Class, @c_Busr5
                , 'Piece Pick Analysis', @c_Facility, @c_AreaKey, @c_PutawayZone, @c_PickZone, @c_LocAisle )

   INSERT INTO #TMP_LOCABC (Type, SkuDescr, StorerKey, SkuGroup, ItemClass, Susr3, Busr1, Class, Busr5
                                , LocDescr, Facility, AreaKey, PutawayZone, PickZone, LocAisle)
   VALUES ( 'CS', 'Case Pick Analysis', @c_StorerKey, @c_SkuGroup, @c_ItemClass, @c_Susr3, @c_Busr1, @c_Class, @c_Busr5
                , 'Case Pick Analysis', @c_Facility, @c_AreaKey, @c_PutawayZone, @c_PickZone, @c_LocAisle )

   INSERT INTO #TMP_LOCABC (Type, SkuDescr, StorerKey, SkuGroup, ItemClass, Susr3, Busr1, Class, Busr5
                                , LocDescr, Facility, AreaKey, PutawayZone, PickZone, LocAisle)
   VALUES ( 'PL', 'Bulk Pick Analysis', @c_StorerKey, @c_SkuGroup, @c_ItemClass, @c_Susr3, @c_Busr1, @c_Class, @c_Busr5
                , 'Bulk Pick Analysis', @c_Facility, @c_AreaKey, @c_PutawayZone, @c_PickZone, @c_LocAisle )

   SELECT Type
         ,SkuDescr 
         ,StorerKey
         ,SkuGroup
         ,ItemClass
         ,Susr3
         ,Busr1
         ,Class
         ,Busr5
         ,LocDescr
         ,Facility             
         ,AreaKey               
         ,PutawayZone           
         ,PickZone              
         ,LocAisle
            
   FROM #TMP_LOCABC 
END

GO