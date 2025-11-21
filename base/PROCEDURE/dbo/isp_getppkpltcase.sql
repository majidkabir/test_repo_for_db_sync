SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: isp_GetPPKPltCase                                  */
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
/* PVCS Version: 1.0	                                                   */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver. Purposes                                 */
/* 08-Feb-2010  SHONG     1.1  Add new Location & ID Parameter          */
/* 18-Feb-2010  SHONG     1.2  Resolve Blocking Issues                  */
/* 17-Mar-2010	NJOW      1.3  Calculate loose qty                      */
/* 28-Jan-2019  TLTING_ext 1.4  enlarge externorderkey field length      */
/************************************************************************/
CREATE PROCEDURE [dbo].[isp_GetPPKPltCase]
   @c_loadkey NVARCHAR(10),
   @c_externorderkey NVARCHAR(50)='',   --tlting_ext
   @c_consigneekey NVARCHAR(15)='',
   @n_totalcarton INT=0 OUTPUT,
   @n_totalpallet INT=0 OUTPUT,
   @n_totalloose  INT=0 OUTPUT,
   @c_LOC NVARCHAR(10)='',
   @c_ID NVARCHAR(18)='',
   @c_Picked NVARCHAR(1)=''
AS
BEGIN
   SET NOCOUNT ON 
   SET ANSI_NULLS OFF 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF
    
    DECLARE @n_continue   INT
           ,@n_cnt        INT
           ,@n_trancount  INT
           ,@c_sku        NVARCHAR(20)
           ,@c_storerkey  NVARCHAR(15)
           ,@c_Compsku    NVARCHAR(20)
           ,@n_Compqty    INT
           ,@c_prepack    NVARCHAR(1)
           ,@n_qty        INT
           ,@n_rowid      INT
    
    CREATE TABLE #TMP_PICKDET(
                Rowid INT IDENTITY(1 ,1)
               ,Storerkey NVARCHAR(15)
               ,Sku NVARCHAR(20)
               ,Altsku NVARCHAR(20)
               ,CartonGroup NVARCHAR(20)
               ,Loc NVARCHAR(10)
               ,Qty INT
               ,Lottable03 NVARCHAR(18)
               ,pkqty INT
               ,[STATUS] NVARCHAR(10)
               ,[Id] NVARCHAR(18)
            )
    
    SELECT @n_continue = 1 
    SELECT @n_trancount = @@TRANCOUNT
    
    WHILE @@TRANCOUNT>0
          COMMIT TRAN
    
    IF @n_continue=1 OR
       @n_continue=2
    BEGIN
        IF ISNULL(RTRIM(@c_LOC) ,'')=''
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
            FROM   LOADPLANDETAIL LD(NOLOCK)
                   JOIN PICKDETAIL PD(NOLOCK)
                        ON  (LD.Orderkey=PD.Orderkey)
                   JOIN LOTATTRIBUTE LA(NOLOCK)
                        ON  (PD.Lot=LA.Lot)
            WHERE  LD.Loadkey = @c_LoadKey AND
                   (
                       LD.Externorderkey=@c_externorderkey OR
                       ISNULL(@c_externorderkey ,'')=''
                   ) AND
                   (
                       LD.Consigneekey=@c_consigneekey OR
                       ISNULL(@c_consigneekey ,'')=''
                   )
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
                FROM   LOADPLANDETAIL LD(NOLOCK)
                       JOIN PICKDETAIL PD(NOLOCK)
                            ON  (LD.Orderkey=PD.Orderkey)
                       JOIN LOTATTRIBUTE LA(NOLOCK)
                            ON  (PD.Lot=LA.Lot)
                WHERE  LD.Loadkey = @c_LoadKey AND
                       PD.LOC = @c_LOC AND
                       (PD.Status BETWEEN '5' AND '8') AND
                       (
                           LD.Externorderkey=@c_externorderkey OR
                           ISNULL(@c_externorderkey ,'')=''
                       ) AND
                       (
                           LD.Consigneekey=@c_consigneekey OR
                           ISNULL(@c_consigneekey ,'')=''
                       )
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
                FROM   LOADPLANDETAIL LD(NOLOCK)
                       JOIN PICKDETAIL PD(NOLOCK)
                            ON  (LD.Orderkey=PD.Orderkey)
                       JOIN LOTATTRIBUTE LA(NOLOCK)
                            ON  (PD.Lot=LA.Lot)
                WHERE  LD.Loadkey = @c_LoadKey AND
                       PD.LOC = @c_LOC AND
                       (PD.Status BETWEEN '0' AND '4') AND
                       (
                           LD.Externorderkey=@c_externorderkey OR
                           ISNULL(@c_externorderkey ,'')=''
                       ) AND
                       (
                           LD.Consigneekey=@c_consigneekey OR
                           ISNULL(@c_consigneekey ,'')=''
                       )
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
                FROM   LOADPLANDETAIL LD(NOLOCK)
                       JOIN PICKDETAIL PD(NOLOCK)
                            ON  (LD.Orderkey=PD.Orderkey)
                       JOIN LOTATTRIBUTE LA(NOLOCK)
                            ON  (PD.Lot=LA.Lot)
                WHERE  LD.Loadkey = @c_LoadKey AND
                       PD.LOC = @c_LOC AND
                       (
                           LD.Externorderkey=@c_externorderkey OR
                           ISNULL(@c_externorderkey ,'')=''
                       ) AND
                       (
                           LD.Consigneekey=@c_consigneekey OR
                           ISNULL(@c_consigneekey ,'')=''
                       )
            END
        END
        
        CREATE TABLE #TMP_BOM  
                (
                    StorerKey    NVARCHAR(15)
                   ,SKU          NVARCHAR(20)
                   ,ComponentSku NVARCHAR(20)
                   ,Qty INT
                )
        
        INSERT INTO #TMP_BOM
        SELECT DISTINCT BM.Storerkey
              ,BM.SKU
              ,BM.ComponentSku
              ,BM.Qty 
               -- INTO #TMP_BOM
        FROM   #TMP_PICKDET TP
               JOIN BILLOFMATERIAL BM(NOLOCK)
                    ON  (TP.Storerkey=BM.Storerkey AND TP.Lottable03=BM.SKU)
        WHERE  ISNULL(RTRIM(TP.AltSku) ,'') = '' AND
               cartongroup<>'PREPACK'
        ORDER BY
               BM.Storerkey
              ,BM.SKU
              ,BM.ComponentSku
        
        CREATE TABLE #TMP_SORT 
                (
                    LOC NVARCHAR(10)
                   ,StorerKey NVARCHAR(15)
                   ,SKU NVARCHAR(20)
                   ,Lottable03 NVARCHAR(18)
                   ,Seq INT
                )
        
        INSERT INTO #TMP_SORT
        SELECT TP.Loc
              ,TP.Storerkey
              ,TP.Sku
              ,TP.Lottable03
              ,SUM(TP.Qty) % ISNULL(BM.Qty ,1) AS Seq
        FROM   #TMP_PICKDET TP
               LEFT JOIN BILLOFMATERIAL BM(NOLOCK)
                    ON  (
                            TP.Storerkey=BM.Storerkey AND
                            TP.Lottable03=BM.SKU AND
                            TP.SKU=BM.Componentsku
                        )
        GROUP BY
               TP.Loc
              ,TP.Storerkey
              ,TP.Sku
              ,TP.Lottable03
              ,BM.qty
        
        UPDATE #TMP_PICKDET
        SET    AltSku = ''
              ,cartongroup = 'STD'
        FROM   #TMP_PICKDET TPD
               LEFT JOIN BILLOFMATERIAL WITH (NOLOCK)
                    ON  (
                            TPD.Storerkey=BILLOFMATERIAL.Storerkey AND
                            TPD.Lottable03=BILLOFMATERIAL.Sku
                        )
        WHERE  BILLOFMATERIAL.Sku IS NULL
        
        SELECT @c_storerkey = ''
              ,@c_sku = ''
        
        DECLARE CUR_BOM CURSOR LOCAL  FAST_FORWARD READ_ONLY FOR
        SELECT DISTINCT Storerkey, SKU
        FROM   #TMP_BOM
        ORDER BY Storerkey, SKU

        OPEN CUR_BOM

        WHILE 1=1
        BEGIN
           FETCH NEXT FROM CUR_BOM INTO @c_storerkey, @c_sku 

           IF @@FETCH_STATUS <> 0
           BEGIN
              CLOSE CUR_BOM 
              DEALLOCATE CUR_BOM 
              BREAK
           END 

            SELECT @c_CompSku = ''
                  ,@c_prepack = 'Y'
            BEGIN TRAN
            WHILE 1=1
            BEGIN
                SELECT TOP 1 
                       @c_storerkey = Storerkey
                      ,@c_compsku = ComponentSku
                      ,@n_compqty = qty
                FROM   #TMP_BOM
                WHERE  Storerkey = @c_storerkey AND
                       Sku = @c_sku AND
                       ComponentSku>@c_compSku
                ORDER BY ComponentSku		       
                
                SELECT @n_cnt = @@ROWCOUNT
               
                
                IF @n_cnt=0
                BEGIN
                    SELECT @c_CompSku = ''
                          ,@c_prepack = 'Y'
   	 	          COMMIT TRAN
   	 	          BEGIN TRAN
   	 	          CONTINUE
                END
                
                WHILE @n_Compqty>0
                BEGIN
                    SELECT TOP 1 @n_rowid = TP.rowid
                          ,@n_qty = TP.qty-TP.pkqty
                    FROM   #TMP_PICKDET TP
                           JOIN #TMP_SORT TS
                                ON  (
                                        TP.Loc=TS.Loc --NJOW04
                                         AND
                                        TP.Storerkey=TS.Storerkey AND
                                        TP.Sku=TS.Sku AND
                                        TP.Lottable03=TS.Lottable03
                                    )
                    WHERE  TP.Storerkey = @c_storerkey AND
                           TP.Sku = @c_compsku AND
                           TP.qty- TP.pkqty>0 AND
                           (
                               (
                                   ISNULL(RTRIM(TP.AltSku) ,'')='' AND
                                   TP.cartongroup<>'PREPACK'
                               ) OR
                               TP.pkqty>0
                           ) AND
                           TP.lottable03 = @c_sku --NJOW02
                    ORDER BY
                           TS.Seq
                          ,2 DESC
                    
                    IF @@ROWCOUNT=0
                    BEGIN
                        SELECT @c_prepack = 'N'
                        BREAK
                    END
                    
                    IF @n_Compqty>=@n_qty
                    BEGIN
                        UPDATE #TMP_PICKDET
                        SET    pkqty = pkqty+@n_qty
                              ,altsku = @c_sku
                              ,cartongroup = 'PREPACK'
                        WHERE  rowid = @n_rowid	  	       	  
                        
                        SELECT @n_Compqty = @n_Compqty- @n_qty
                    END
                    ELSE
                    BEGIN
                        UPDATE #TMP_PICKDET
                        SET    pkqty = pkqty+@n_Compqty
                              ,altsku = @c_sku
                              ,cartongroup = 'PREPACK'
                        WHERE  rowid = @n_rowid	  	       	  
                        
                        SELECT @n_Compqty = 0
                    END
                END -- while 3
                IF @c_prepack='N'
                BEGIN
     	 	       	  ROLLBACK TRAN
                    BREAK
                END
            END -- while 2
        END -- while 1		 
        
        
        CREATE TABLE #TMP_PICKDET2  
                (
                    Storerkey NVARCHAR(15)
                   ,Sku NVARCHAR(20)
                   ,Altsku NVARCHAR(20)
                   ,CartonGroup NVARCHAR(20)
                   ,Loc NVARCHAR(10)
                   ,Qty INT
                   ,STATUS NVARCHAR(10)
                   ,Id NVARCHAR(18)
                   ,Casecnt INT
                   ,Palletcnt INT
                ) 
        
        INSERT INTO #TMP_PICKDET2
        SELECT Storerkey
              ,Sku
              ,Altsku
              ,CartonGroup
              ,Loc
              ,Qty
              ,STATUS
              ,Id
              ,CONVERT(INT ,0) AS Casecnt
              ,CONVERT(INT ,0) AS Palletcnt
        FROM   #TMP_PICKDET
        WHERE  pkqty = 0
        
        INSERT INTO #TMP_PICKDET2
        SELECT Storerkey
              ,Sku
              ,Altsku
              ,CartonGroup
              ,Loc
              ,pkqty
              ,STATUS
              ,Id
              ,0
              ,0
        FROM   #TMP_PICKDET
        WHERE  pkqty>0
        
        INSERT INTO #TMP_PICKDET2
        SELECT Storerkey
              ,Sku
              ,Altsku
              ,'PPKLOOSE'
              ,Loc
              ,qty- pkqty
              ,STATUS
              ,Id
              ,0
              ,0
        FROM   #TMP_PICKDET
        WHERE  pkqty>0 AND
               qty- pkqty>0
    END -- continue  

    WHILE @@TRANCOUNT < @n_trancount 
    BEGIN
        BEGIN TRAN
        SELECT @n_trancount = @n_trancount- 1
    END
    
    IF @n_continue=1 OR
       @n_continue=2
    BEGIN
        UPDATE #TMP_PICKDET2
        SET    casecnt = PACK.Casecnt
              ,palletcnt = PACK.Pallet
        FROM   #TMP_PICKDET2 TPD2
               JOIN UPC(NOLOCK)
                    ON  (
                            TPD2.Storerkey=UPC.Storerkey AND
                            TPD2.Altsku=UPC.Sku AND
                            TPD2.Cartongroup IN ('PREPACK' ,'PPKLOOSE') AND
                            UPC.UOM='CS'
                        )
               JOIN PACK(NOLOCK)
                    ON  (UPC.Packkey=PACK.Packkey)
        
        UPDATE #TMP_PICKDET2
        SET    casecnt = PACK.Casecnt
              ,palletcnt = PACK.Pallet
        FROM   #TMP_PICKDET2 TPD2
               JOIN SKU(NOLOCK)
                    ON  (TPD2.Storerkey=SKU.Storerkey AND TPD2.Sku=SKU.Sku)
               JOIN PACK(NOLOCK)
                    ON  (SKU.Packkey=PACK.Packkey)
        WHERE  TPD2.Cartongroup NOT IN ('PREPACK' ,'PPKLOOSE')
        
        CREATE TABLE #TMP_BOMQTY  
                (Storerkey NVARCHAR(15) ,Sku NVARCHAR(20) ,totqty INT)
        
        INSERT INTO #TMP_BOMQTY
        SELECT BOM.Storerkey
              ,BOM.Sku
              ,SUM(BOM.qty) AS totqty
        FROM   (
                   SELECT DISTINCT storerkey
                         ,altsku
                   FROM   #TMP_PICKDET2
               ) PD
               JOIN BILLOFMATERIAL BOM(NOLOCK)
                    ON  (PD.Storerkey=BOM.Storerkey AND PD.Altsku=BOM.sku)
        GROUP BY
               BOM.Storerkey
              ,BOM.Sku
        
        SELECT TP.Storerkey
              ,TP.Altsku AS sku
              ,TP.id
              ,TP.Loc
              ,CASE 
                    WHEN TP.Casecnt>0 THEN FLOOR(SUM(TP.Qty)/(TP.Casecnt*BQ.totqty))
                    ELSE 0
               END AS totctn
              ,CASE 
                    WHEN TP.Palletcnt>0 THEN FLOOR(SUM(TP.Qty)/(TP.Palletcnt*BQ.totqty))
                    ELSE CASE 
                              WHEN TP.Casecnt>0 THEN FLOOR((SUM(TP.Qty)/(TP.Casecnt*BQ.totqty)) 
                                  /60)
                              ELSE 0
                         END
               END AS totplt
               ,CASE 
                    WHEN TP.Casecnt > 0 THEN SUM(TP.Qty) % (TP.Casecnt*BQ.totqty)
                    ELSE SUM(TP.Qty)
               END AS totloose
               INTO #TMP_RESULT_PPK
        FROM   #TMP_PICKDET2 TP
               JOIN #TMP_BOMQTY BQ
                    ON  (TP.Storerkey=BQ.Storerkey AND TP.Altsku=BQ.sku)
        WHERE  TP.Cartongroup IN ('PREPACK' ,'PPKLOOSE')
        GROUP BY
               TP.Storerkey
              ,TP.Altsku
              ,TP.id
              ,TP.Loc
              ,TP.Casecnt
              ,TP.Palletcnt
              ,BQ.totqty
        
        SELECT TP.Storerkey
              ,TP.sku
              ,TP.id
              ,TP.Loc
              ,CASE 
                    WHEN TP.Casecnt>0 THEN FLOOR(SUM(TP.Qty)/TP.Casecnt)
                    ELSE 0
               END AS totctn
              ,CASE 
                    WHEN TP.Palletcnt>0 THEN FLOOR(SUM(TP.Qty)/TP.Palletcnt)
                    ELSE CASE 
                              WHEN TP.Casecnt>0 THEN FLOOR((SUM(TP.Qty)/TP.Casecnt)/60)
                              ELSE 0
                         END
               END AS totplt
               ,CASE 
                    WHEN TP.Casecnt > 0 THEN SUM(TP.Qty) % TP.Casecnt
                    ELSE SUM(TP.Qty)
               END AS totloose
               INTO #TMP_RESULT_STD
        FROM   #TMP_PICKDET2 TP
        WHERE  TP.Cartongroup NOT IN ('PREPACK' ,'PPKLOOSE')
        GROUP BY
               TP.Storerkey
              ,TP.sku
              ,TP.id
              ,TP.Loc
              ,TP.Casecnt
              ,TP.Palletcnt     
        
        SELECT @n_totalcarton = SUM(totctn)
              ,@n_totalpallet = SUM(totplt)
              ,@n_totalloose = SUM(totloose)
        FROM   (
                   SELECT totctn
                         ,totplt
                         ,totloose
                   FROM   #TMP_RESULT_PPK(NOLOCK) UNION ALL SELECT totctn
                                                                  ,totplt
                                                                  ,totloose
                                                            FROM   
                                                                   #TMP_RESULT_STD(NOLOCK)
               ) REL         
        
        IF @n_totalcarton IS NULL
            SET @n_totalcarton = 0
        
        IF @n_totalpallet IS NULL
            SET @n_totalpallet = 0

        IF @n_totalloose IS NULL
            SET @n_totalloose = 0
    END
END

GO