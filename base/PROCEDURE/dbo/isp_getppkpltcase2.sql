SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/    
/* Stored Procedure: isp_GetPPKPltCase2                                 */    
/* Creation Date:                                                       */    
/* Copyright: IDS                                                       */    
/* Written by: NJOW                                                     */    
/*                                                                      */    
/* Purpose:                                                             */    
/*                                                                      */    
/* Called By:                                                           */     
/*                                                                      */    
/* Parameters: (Input)  Loadkey, externorderkey, consigneekey           */    
/*                                                                      */    
/* PVCS Version: 1.9                                                    */    
/*                                                                      */    
/* Version: 5.4                                                         */    
/*                                                                      */    
/* Data Modifications:                                                  */    
/*                                                                      */    
/* Updates:                                                             */    
/* Date         Author    Ver. Purposes                                 */    
/* 08-Feb-2010  SHONG     1.1  Add new Location & ID Parameter          */    
/* 18-Feb-2010  SHONG     1.2  Resolve Blocking Issues                  */    
/* 17-Mar-2010  NJOW      1.3  Calculate loose qty                      */    
/* 06-May-2010  SHONG     1.4  Simplify the Carton Calculation          */  
/* 07-May-2010  Vicky     1.5  Take out the pointing to IDSUS db        */  
/* 13-May-2010  SHONG     1.6  Filter PickDetail.Status < '9'           */
/* 27-May-2010  Vicky     1.7  Should not filter PickDetail.Status = 9  */
/*                             (Vicky01)                                */
/* 21-Feb-2012  Shong     1.8  Performance Tuning                       */
/* 23-Mar-2012  YTwan     1.9  Add Parameter Storerkey, Wavekey,        */
/*                             Sectionkey & Areakey.(Wan01)             */
/*                             Fixed.(Wan02)                            */
/* 13-Apr-2012  YTwan     1.4  SOS#238874.Add Parameter Aisle.(Wan03)   */
/* 28-Jan-2019  TLTING_ext 1.5  enlarge externorderkey field length      */
/************************************************************************/    
CREATE PROCEDURE [dbo].[isp_GetPPKPltCase2]  
   @c_LoadKey NVARCHAR(10),  
   @c_ExternOrderkey NVARCHAR(50)='',    --tlting_ext
   @c_ConsigneeKey NVARCHAR(15)='',  
   @n_TotalCarton INT=0 OUTPUT,  
   @n_TotalPallet INT=0 OUTPUT,  
   @n_TotalLoose INT=0 OUTPUT,  
   @c_LOC NVARCHAR(10)='',  
   @c_ID NVARCHAR(18)='',  
   @c_Picked NVARCHAR(1)='',   
   @c_GetTotPallet NVARCHAR(1)='Y', 
   @c_Storerkey  NVARCHAR(15)='',                                                                   --(Wan01)
   @c_Wavekey    NVARCHAR(10)='',                                                                   --(Wan01)
   @c_Sectionkey NVARCHAR(10)='',                                                                   --(Wan01)
   @c_Areakey    NVARCHAR(10)='',                                                                   --(Wan01) 
   @c_Aisle      NVARCHAR(10)=''                                                                    --(Wan03) 
AS  
BEGIN  
   SET NOCOUNT ON 
   SET ANSI_NULLS OFF 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF  
      
    SET @c_GetTotPallet = ISNULL(@c_GetTotPallet,'Y')  
  
    DECLARE @n_Continue    INT  
           ,@n_Cnt         INT  
           ,@n_Trancount   INT  
           ,@c_Sku         NVARCHAR(20)  
           --,@c_StorerKey   NVARCHAR(15)                                                             --(Wan01)
           ,@c_Compsku     NVARCHAR(20)  
           ,@n_Compqty     INT  
           ,@c_Prepack     NVARCHAR(1)  
           ,@n_QTY         INT  
           ,@n_Rowid       INT  
           ,@n_CaseCnt     INT   
           ,@n_CartonCtns  INT  
           ,@n_LooseCnts   INT  
           ,@n_TotalBOMQty INT  
      
    CREATE TABLE #TMP_PICKDET  
    (  
       Rowid         INT IDENTITY(1 ,1)  
       ,Storerkey    NVARCHAR(15)  
       ,Sku          NVARCHAR(20)  
       ,Altsku       NVARCHAR(20)  
       ,CartonGroup  NVARCHAR(20)  
       ,Loc          NVARCHAR(10)  
       ,Qty          INT  
       ,Lottable03   NVARCHAR(18)  
       ,pkqty        INT  
       ,[STATUS]     NVARCHAR(10)  
       ,[Id]         NVARCHAR(18)  
    )    
      
    SELECT @n_continue = 1     
    SELECT @n_trancount = @@TRANCOUNT    
  
    SET @n_TotalCarton = 0  
    SET @n_TotalLoose = 0   
    SET @n_TotalPallet = 0  
      
     
    IF @n_continue=1 OR @n_continue=2  
    BEGIN  
        IF ISNULL(RTRIM(@c_LOC) ,'')=''  
        BEGIN 
            --(Wan03) - START 
            IF @c_Picked='Y' 
            BEGIN
               INSERT INTO #TMP_PICKDET  
                 (  
                   Storerkey, Sku, Altsku, CartonGroup, Loc, Qty, Lottable03, pkqty,   
                   [STATUS], Id  
                 )  
               SELECT PD.Storerkey  
                     ,PD.Sku  
                     ,PD.Altsku  
                     ,PD.CartonGroup  
                     ,PD.Loc  
                     ,PD.Qty  
                     ,LA.Lottable03  
                     ,CONVERT(INT ,0) AS pkqty  
                     ,PD.Status  
                     ,PD.Id  
               FROM ORDERS O  (NOLOCK)  
               JOIN PICKDETAIL PD(NOLOCK) ON (O.Orderkey=PD.Orderkey)   
               JOIN LOTATTRIBUTE LA(NOLOCK) ON (PD.Lot=LA.Lot) 
               JOIN LOC WITH (NOLOCK) ON (PD.Loc = LOC.loc)
               LEFT JOIN AREADETAIL WITH (NOLOCK) ON (LOC.PutawayZone = AREADETAIL.PutawayZone)
               WHERE (O.Storerkey = CASE WHEN ISNULL(@c_Storerkey ,'')='' THEN O.Storerkey ELSE @c_Storerkey END) 
                 AND (O.Loadkey = CASE WHEN ISNULL(@c_LoadKey ,'')='' THEN O.Loadkey ELSE @c_LoadKey END)
                 AND (O.UserDefine09 = CASE WHEN ISNULL(@c_WaveKey ,'')='' THEN O.UserDefine09 ELSE @c_WaveKey END)  
                 AND (O.Externorderkey= CASE WHEN ISNULL(@c_ExternOrderkey ,'')='' THEN O.Externorderkey ELSE @c_ExternOrderkey END )   
                 AND (O.Consigneekey= CASE WHEN ISNULL(@c_ConsigneeKey ,'')='' THEN O.Consigneekey ELSE @c_ConsigneeKey END ) 
                 AND (LOC.SectionKey = CASE WHEN ISNULL(@c_SectionKey ,'')='' THEN LOC.SectionKey ELSE @c_SectionKey END)
                 --(Wan03) - START
                 AND (LOC.LocAisle = CASE WHEN ISNULL(@c_Aisle ,'')='' THEN LOC.LocAisle ELSE @c_Aisle END)
                 --(Wan03) - END
                 AND (ISNULL(AREADETAIL.AreaKey,'') = CASE WHEN ISNULL(@c_AreaKey ,'')='' THEN ISNULL(AREADETAIL.AreaKey,'') ELSE @c_AreaKey END)
                 AND (PD.Status BETWEEN '5' AND '9')    
            END
            ELSE IF @c_Picked='N' 
            BEGIN
               INSERT INTO #TMP_PICKDET  
                 (  
                   Storerkey, Sku, Altsku, CartonGroup, Loc, Qty, Lottable03, pkqty,   
                   [STATUS], Id  
                 )  
               SELECT PD.Storerkey  
                     ,PD.Sku  
                     ,PD.Altsku  
                     ,PD.CartonGroup  
                     ,PD.Loc  
                     ,PD.Qty  
                     ,LA.Lottable03  
                     ,CONVERT(INT ,0) AS pkqty  
                     ,PD.Status  
                     ,PD.Id  
               FROM ORDERS O  (NOLOCK)  
               JOIN PICKDETAIL PD(NOLOCK) ON (O.Orderkey=PD.Orderkey)   
               JOIN LOTATTRIBUTE LA(NOLOCK) ON (PD.Lot=LA.Lot) 
               JOIN LOC WITH (NOLOCK) ON (PD.Loc = LOC.loc)
               LEFT JOIN AREADETAIL WITH (NOLOCK) ON (LOC.PutawayZone = AREADETAIL.PutawayZone)
               WHERE (O.Storerkey = CASE WHEN ISNULL(@c_Storerkey ,'')='' THEN O.Storerkey ELSE @c_Storerkey END) 
                 AND (O.Loadkey = CASE WHEN ISNULL(@c_LoadKey ,'')='' THEN O.Loadkey ELSE @c_LoadKey END)
                 AND (O.UserDefine09 = CASE WHEN ISNULL(@c_WaveKey ,'')='' THEN O.UserDefine09 ELSE @c_WaveKey END)  
                 AND (O.Externorderkey= CASE WHEN ISNULL(@c_ExternOrderkey ,'')='' THEN O.Externorderkey ELSE @c_ExternOrderkey END )   
                 AND (O.Consigneekey= CASE WHEN ISNULL(@c_ConsigneeKey ,'')='' THEN O.Consigneekey ELSE @c_ConsigneeKey END ) 
                 AND (LOC.SectionKey = CASE WHEN ISNULL(@c_SectionKey ,'')='' THEN LOC.SectionKey ELSE @c_SectionKey END)
                 --(Wan03) - START 
                 AND (LOC.LocAisle = CASE WHEN ISNULL(@c_Aisle ,'')='' THEN LOC.LocAisle ELSE @c_Aisle END)
                 --(Wan03) - END 
                 AND (ISNULL(AREADETAIL.AreaKey,'') = CASE WHEN ISNULL(@c_AreaKey ,'')='' THEN ISNULL(AREADETAIL.AreaKey,'') ELSE @c_AreaKey END)
                 AND (PD.Status BETWEEN '0' AND '4') 
            END
            ELSE 
            BEGIN 
            --(Wan03) - END  
            INSERT INTO #TMP_PICKDET  
              (  
                Storerkey, Sku, Altsku, CartonGroup, Loc, Qty, Lottable03, pkqty,   
                [STATUS], Id  
              )  
            SELECT PD.Storerkey  
                  ,PD.Sku  
                  ,PD.Altsku  
                  ,PD.CartonGroup  
                  ,PD.Loc  
                  ,PD.Qty  
                  ,LA.Lottable03  
                  ,CONVERT(INT ,0) AS pkqty  
                  ,PD.Status  
                  ,PD.Id  
            FROM ORDERS O  (NOLOCK)  
            JOIN PICKDETAIL PD(NOLOCK) ON (O.Orderkey=PD.Orderkey)   
            JOIN LOTATTRIBUTE LA(NOLOCK) ON (PD.Lot=LA.Lot) 
            --(Wan01) - START 
            JOIN LOC WITH (NOLOCK) ON (PD.Loc = LOC.loc)
            LEFT JOIN AREADETAIL WITH (NOLOCK) ON (LOC.PutawayZone = AREADETAIL.PutawayZone)
            WHERE (O.Storerkey = CASE WHEN ISNULL(@c_Storerkey ,'')='' THEN O.Storerkey ELSE @c_Storerkey END) 
              AND (O.Loadkey = CASE WHEN ISNULL(@c_LoadKey ,'')='' THEN O.Loadkey ELSE @c_LoadKey END)
              AND (O.UserDefine09 = CASE WHEN ISNULL(@c_WaveKey ,'')='' THEN O.UserDefine09 ELSE @c_WaveKey END)  
            --WHERE  O.Loadkey = @c_LoadKey 
            --(Wan01) - END  
              AND (O.Externorderkey= CASE WHEN ISNULL(@c_ExternOrderkey ,'')='' THEN O.Externorderkey ELSE @c_ExternOrderkey END )   
              AND (O.Consigneekey= CASE WHEN ISNULL(@c_ConsigneeKey ,'')='' THEN O.Consigneekey ELSE @c_ConsigneeKey END ) 
            --(Wan01) - START              
              AND (LOC.SectionKey = CASE WHEN ISNULL(@c_SectionKey ,'')='' THEN LOC.SectionKey ELSE @c_SectionKey END)
              AND (LOC.LocAisle = CASE WHEN ISNULL(@c_Aisle ,'')='' THEN LOC.LocAisle ELSE @c_Aisle END)       --(Wan03)              
              AND (ISNULL(AREADETAIL.AreaKey,'') = CASE WHEN ISNULL(@c_AreaKey ,'')='' THEN ISNULL(AREADETAIL.AreaKey,'') ELSE @c_AreaKey END)  
            --(Wan01) - END  
           END --(Wan03)
        END  
        ELSE  
        BEGIN  
            IF @c_Picked='Y'  
            BEGIN  
                INSERT INTO #TMP_PICKDET  
                  (  
                    Storerkey, Sku, Altsku, CartonGroup, Loc, Qty, Lottable03,   
                    pkqty, [STATUS], Id  
                  )  
                SELECT PD.Storerkey  
                      ,PD.Sku  
                      ,PD.Altsku  
                      ,PD.CartonGroup  
                      ,PD.Loc  
                      ,PD.Qty  
                      ,LA.Lottable03  
                      ,CONVERT(INT ,0) AS pkqty  
                      ,PD.Status  
                      ,PD.Id  
                FROM   ORDERS O (NOLOCK)  
                       JOIN PICKDETAIL PD(NOLOCK)  
                            ON  (O.Orderkey=PD.Orderkey)  
                       JOIN LOTATTRIBUTE LA(NOLOCK)  
                            ON  (PD.Lot=LA.Lot) 
               --(Wan01) - START 
               JOIN LOC WITH (NOLOCK) ON (PD.Loc = LOC.loc)
               LEFT JOIN AREADETAIL WITH (NOLOCK) ON (LOC.PutawayZone = AREADETAIL.PutawayZone)
               --WHERE  O.Loadkey = @c_LoadKey 
               --      AND ( PD.LOC = @c_LOC ) 
               WHERE  ( PD.LOC = @c_LOC ) 
               --(Wan01) - END 
                       AND (PD.Status BETWEEN '5' AND '9')  
                       AND (O.Externorderkey= CASE WHEN ISNULL(@c_ExternOrderkey ,'')='' THEN O.Externorderkey ELSE @c_ExternOrderkey END )  
                       AND (O.Consigneekey= CASE WHEN ISNULL(@c_ConsigneeKey ,'')='' THEN O.Consigneekey ELSE @c_ConsigneeKey END )  
               --(Wan01) - START 
                 AND (O.Storerkey = CASE WHEN ISNULL(@c_Storerkey ,'')='' THEN O.Storerkey ELSE @c_Storerkey END) 
                 AND (O.Loadkey = CASE WHEN ISNULL(@c_LoadKey ,'')='' THEN O.Loadkey ELSE @c_LoadKey END)
                 AND (O.UserDefine09 = CASE WHEN ISNULL(@c_WaveKey ,'')='' THEN O.UserDefine09 ELSE @c_WaveKey END)               
                 AND (LOC.SectionKey = CASE WHEN ISNULL(@c_SectionKey ,'')='' THEN LOC.SectionKey ELSE @c_SectionKey END)
                 --(Wan03) - START 
                 AND (LOC.LocAisle = CASE WHEN ISNULL(@c_Aisle ,'')='' THEN LOC.LocAisle ELSE @c_Aisle END)
                 --(Wan03) - END                  
                 AND (ISNULL(AREADETAIL.AreaKey,'') = CASE WHEN ISNULL(@c_AreaKey ,'')='' THEN ISNULL(AREADETAIL.AreaKey,'') ELSE @c_AreaKey END)  
               --(Wan01) - END 
            END  
            ELSE     
            IF @c_Picked='N'  
            BEGIN  
                INSERT INTO #TMP_PICKDET  
                  (  
                    Storerkey, Sku, Altsku, CartonGroup, Loc, Qty, Lottable03,   
                    pkqty, [STATUS], Id  
                  )  
                SELECT PD.Storerkey  
                      ,PD.Sku  
                      ,PD.Altsku  
                      ,PD.CartonGroup  
                      ,PD.Loc  
                      ,PD.Qty  
                      ,LA.Lottable03  
                      ,CONVERT(INT ,0) AS pkqty  
                      ,PD.Status  
                      ,PD.Id  
                FROM   ORDERS O (NOLOCK)  
                       JOIN PICKDETAIL PD(NOLOCK)  
                            ON  (O.Orderkey=PD.Orderkey)  
                       JOIN LOTATTRIBUTE LA(NOLOCK)  
                            ON  (PD.Lot=LA.Lot)  
                --(Wan01) - START 
                     JOIN LOC WITH (NOLOCK) ON (PD.Loc = LOC.loc)
                     LEFT JOIN AREADETAIL WITH (NOLOCK) ON (LOC.PutawayZone = AREADETAIL.PutawayZone)
                --WHERE  O.Loadkey = @c_LoadKey  
                --       AND (PD.LOC = @c_LOC )  
                WHERE  ( PD.LOC = @c_LOC )
                --(Wan01) - END 
                       AND (PD.Status BETWEEN '0' AND '4')  
                       AND (O.Externorderkey= CASE WHEN ISNULL(@c_ExternOrderkey ,'')='' THEN O.Externorderkey ELSE @c_ExternOrderkey END )  
                       AND (O.Consigneekey= CASE WHEN ISNULL(@c_ConsigneeKey ,'')='' THEN O.Consigneekey ELSE @c_ConsigneeKey END ) 
                --(Wan01) - START 
                       AND (O.Storerkey = CASE WHEN ISNULL(@c_Storerkey ,'')='' THEN O.Storerkey ELSE @c_Storerkey END) 
                       AND (O.Loadkey = CASE WHEN ISNULL(@c_LoadKey ,'')='' THEN O.Loadkey ELSE @c_LoadKey END)
                       AND (O.UserDefine09 = CASE WHEN ISNULL(@c_WaveKey ,'')='' THEN O.UserDefine09 ELSE @c_WaveKey END)               
                       AND (LOC.SectionKey = CASE WHEN ISNULL(@c_SectionKey ,'')='' THEN LOC.SectionKey ELSE @c_SectionKey END)
                       AND (LOC.LocAisle = CASE WHEN ISNULL(@c_Aisle ,'')='' THEN LOC.LocAisle ELSE @c_Aisle END)       --(Wan03)                       
                       AND (ISNULL(AREADETAIL.AreaKey,'') = CASE WHEN ISNULL(@c_AreaKey ,'')='' THEN ISNULL(AREADETAIL.AreaKey,'') ELSE @c_AreaKey END)  
                --(Wan01) - END  
            END  
            ELSE  
            BEGIN  
                INSERT INTO #TMP_PICKDET  
                  (  
                    Storerkey, Sku, Altsku, CartonGroup, Loc, Qty, Lottable03,   
                    pkqty, [STATUS], Id  
                  )  
                SELECT PD.Storerkey  
                      ,PD.Sku  
                      ,PD.Altsku  
                      ,PD.CartonGroup  
                      ,PD.Loc  
                      ,PD.Qty  
                      ,LA.Lottable03  
                      ,CONVERT(INT ,0) AS pkqty  
                      ,PD.Status  
                      ,PD.Id  
                FROM   ORDERS O (NOLOCK)  
                       JOIN PICKDETAIL PD(NOLOCK)  
                            ON  (O.Orderkey=PD.Orderkey)  
                       JOIN LOTATTRIBUTE LA(NOLOCK)  
                            ON  (PD.Lot=LA.Lot)  
                --(Wan01) - START 
                     JOIN LOC WITH (NOLOCK) ON (PD.Loc = LOC.loc)
                     LEFT JOIN AREADETAIL WITH (NOLOCK) ON (LOC.PutawayZone = AREADETAIL.PutawayZone)
                --WHERE  O.Loadkey = @c_LoadKey   
                --       AND PD.Status <= '9' -- Added By SHONG ON 13-MAY-2010 (Vicky01)
                WHERE  PD.Status <= '9'
                --(Wan01) - END 
                       AND (PD.LOC = @c_LOC ) 
                       AND (O.Externorderkey= CASE WHEN ISNULL(@c_ExternOrderkey ,'')='' THEN O.Externorderkey ELSE @c_ExternOrderkey END )  
                       AND (O.Consigneekey= CASE WHEN ISNULL(@c_ConsigneeKey ,'')='' THEN O.Consigneekey ELSE @c_ConsigneeKey END ) 
                --(Wan01) - START 
                       AND (O.Storerkey = CASE WHEN ISNULL(@c_Storerkey ,'')='' THEN O.Storerkey ELSE @c_Storerkey END) 
                       AND (O.Loadkey = CASE WHEN ISNULL(@c_LoadKey ,'')='' THEN O.Loadkey ELSE @c_LoadKey END)
                       AND (O.UserDefine09 = CASE WHEN ISNULL(@c_WaveKey ,'')='' THEN O.UserDefine09 ELSE @c_WaveKey END)               
                       AND (LOC.SectionKey = CASE WHEN ISNULL(@c_SectionKey ,'')='' THEN LOC.SectionKey ELSE @c_SectionKey END)
                       AND (LOC.LocAisle = CASE WHEN ISNULL(@c_Aisle ,'')='' THEN LOC.LocAisle ELSE @c_Aisle END)  --(Wan03)
                       AND (ISNULL(AREADETAIL.AreaKey,'') = CASE WHEN ISNULL(@c_AreaKey ,'')='' THEN ISNULL(AREADETAIL.AreaKey,'') ELSE @c_AreaKey END)   
                --(Wan01) - END   
            END  
        END    
 
        DECLARE CUR_PrePackQty  CURSOR LOCAL FAST_FORWARD READ_ONLY   
        FOR  
            SELECT T.Storerkey  
                  ,T.Lottable03 AS ALTSKU  
                  ,T.LOC  
                  ,T.ID  
                  ,SUM(T.Qty) AS Qty  
                  ,ISNULL(p.CaseCnt ,0)  
            FROM   #TMP_PICKDET T  
                   LEFT OUTER JOIN UPC U WITH (NOLOCK)  
                        ON  U.Storerkey = T.Storerkey  
                            AND U.Sku = T.Lottable03  
                            AND U.UOM = 'CS'  
                   LEFT OUTER JOIN PACK p WITH (NOLOCK)  
                        ON  p.PackKey = u.PackKey  
            GROUP BY  
                   T.Storerkey  
                  ,T.Lottable03  
                  ,T.LOC  
                  ,T.ID  
                  ,ISNULL(p.CaseCnt ,0)  
          
        OPEN CUR_PrePackQty  
          
        FETCH NEXT FROM CUR_PrePackQty INTO @c_storerkey, @c_sku, @c_LOC, @c_ID,   
        @n_QTY, @n_CaseCnt                                   
          
        WHILE @@FETCH_STATUS<>-1  
        BEGIN  
           IF @c_GetTotPallet = 'Y'  
           BEGIN   
              -- If Total Allocated = Total Qty by ID  
              -- Then this is the Pallet Pick   
              IF @n_QTY=(  
                     SELECT SUM(Qty)  
                     FROM   LOTxLOCxID WITH (NOLOCK)  
                     WHERE  LOC = @c_LOC  
                            AND ID = @c_ID  
                 )  
              BEGIN  
                  SET @n_TotalPallet = @n_TotalPallet+1  
                  GOTO NEXT_FETCH                                                                  --(Wan02) 
              END  
           END -- Get Pallet = Y  
             
           IF @n_CaseCnt>0  
           BEGIN  
               SET @n_TotalBOMQty = 0  
               SELECT @n_TotalBOMQty = SUM(BOM.QTY)  
               FROM   BillOfMaterial BOM WITH (NOLOCK)  
               WHERE  BOM.Storerkey = @c_StorerKey  
                      AND BOM.SKU = @c_SKU  
                 
               SET @n_CartonCtns = CEILING(@n_QTY/(@n_TotalBOMQty*@n_CaseCnt))  
                 
               SET @n_LooseCnts = (@n_QTY %(@n_TotalBOMQty*@n_CaseCnt))  
           END  
           ELSE  
           BEGIN  
               SET @n_CartonCtns = 0  
               SET @n_LooseCnts = @n_QTY  
           END  
  
           SET @n_TotalCarton = @n_TotalCarton + @n_CartonCtns  
           SET @n_TotalLoose  = @n_TotalLoose  + @n_LooseCnts   
              
           NEXT_FETCH:                                                                             --(Wan02)
           FETCH NEXT FROM CUR_PrePackQty INTO @c_storerkey, @c_sku, @c_LOC, @c_ID,   
           @n_QTY, @n_CaseCnt    
        END                  
          
        IF @n_TotalCarton IS NULL  
            SET @n_TotalCarton = 0    
          
        IF @n_TotalPallet IS NULL  
            SET @n_TotalPallet = 0    
          
        IF @n_TotalLoose IS NULL  
         SET @n_TotalLoose = 0  
    END  
END 

GO