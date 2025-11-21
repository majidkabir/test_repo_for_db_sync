SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: isp_PrintManifestLabel_RDT                         */
/* Creation Date: 20-MAR-2018                                           */
/* Copyright: IDS                                                       */
/* Written by: CSCHONG                                                  */
/*                                                                      */
/* Purpose: To print pallet manifest. (WMS-4245)                        */
/*                                                                      */
/* Called By: RDT                                                       */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Purposes                                      */
/************************************************************************/

CREATE PROC [dbo].[isp_PrintManifestLabel_RDT] (
       @c_OrderKey       NVARCHAR(10) = '', 
       @c_dropid       NVARCHAR(18) = ''
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF   

   DECLARE @n_continue    int,
           @c_errmsg      NVARCHAR(255),
           @b_success     int,
           @n_err         int, 
           @b_debug       int

Set @b_debug = 0

DECLARE  @n_cnt INT,
         @c_getOrderkey NVARCHAR(10),
         @c_getdropid   NVARCHAR(18),
         @c_udf05       NVARCHAR(10),
         @n_casecnt     FLOAT,
         @c_door        NVARCHAR(10),
         @c_stop        NVARCHAR(10),
         @n_CntDropid   INT,
         @n_TTLPLT      INT,
         @n_CurrDropID  INT,
         @c_sku         NVARCHAR(20),
         @n_getcasecnt  FLOAT,
         @c_storerkey   NVARCHAR(20),
         @n_qtypcs      INT,
         @n_ppacqty     INT,
         @n_rowid       INT

 

   CREATE TABLE #TEMP_MANIFESTRDT  (
      
         ExternOrderkey   NVARCHAR(30) NULL,
         BuyerPO          NVARCHAR(20) NULL,
         PPALOTT04        DATETIME NULL,
         PPACQTY          INT  NULL,
         deliverdate      datetime,
         dropid           NVARCHAR(18) NULL,
         storerkey        NVARCHAR(15) NULL,
         CSKU             NVARCHAR(20) NULL,
         STCompany        NVARCHAR(45) NULL, 
         STFAX2           NVARCHAR(45) NULL,
         SDESCR           NVARCHAR(100) NULL,
         CurrentPLT       int,   
         TTLPLT           int,   
         sku              NVARCHAR(20) NULL,
         Orderkey         NVARCHAR(20) NULL,
         CASECNT          FLOAT  NULL,
         qtypcs           INT  NULL,
         rowid            int IDENTITY(1,1)   )
         
         
     CREATE TABLE #TEMPRDTCTNMANIFEST (
     RowID INT IDENTITY(1,1) NOT NULL, 
     Orderkey NVARCHAR(20) NULL,
     Dropid   NVARCHAR(20) NULL  
     )

        INSERT INTO #TEMP_MANIFESTRDT
        (
         ExternOrderkey,
         BuyerPO,
         PPALOTT04,
         PPACQTY,
         deliverdate,
         dropid,
         storerkey,
         CSKU,
         STCompany,
         STFAX2,
         SDESCR,
         CurrentPLT,
         TTLPLT,
         sku,
         Orderkey,
         CASECNT,
         qtypcs 
        )
 
        SELECT ISNULL(ORDERS.ExternOrderKey,'') AS ExternOrderKey,
            ISNULL(ORDERS.buyerPO,'') AS BuyerPO,  
            RDTPPA.lottable04 AS PPALOTT04,  
            ISNULL(RDTPPA.cqty,1) AS PPACQTY,  
            ISNULL(ORDERS.DeliveryDate,'') AS DeliveryDate,
            PICKDETAIL.DropID, 
            PICKDETAIL.Storerkey,   
            CS.consigneesku,    
            Storer.Company, 
            Storer.Fax2, 
            SKU.descr,
            0,0,
            RDTPPA.Sku,
            ORDERS.OrderKey,
             CASE WHEN ISNULL(CONVERT(FLOAT,CS.CrossSKUQty),0) <> 0 THEN CONVERT(FLOAT,CS.CrossSKUQty) ELSE PACK.casecnt END,
            0
        FROM PICKDETAIL   WITH (NOLOCK) 
        JOIN SKU     WITH (NOLOCK) ON ( PICKDETAIL.Storerkey = SKU.StorerKey ) and     
                                 ( PICKDETAIL.Sku = SKU.Sku )     
        JOIN ORDERS   WITH (NOLOCK) ON ( PICKDETAIL.OrderKey = ORDERS.OrderKey ) 
        JOIN ORDERDETAIL OD WITH (NOLOCK) ON OD.Orderkey=ORDERS.OrderKey    
        JOIN Storer WITH (NOLOCK) on ( Storer.StorerKey = ORDERS.ConsigneeKey )  
        LEFT JOIN CONSIGNEESKU CS WITH (NOLOCK) ON CS.Sku=PICKDETAIL.SKU AND CS.consigneekey = ORDERS.consigneekey
                                                AND CS.storerkey = OD.storerkey
        JOIN PACK WITH (NOLOCK) on ( PACK.PackKey = PICKDETAIL.PackKey )  
        LEFT JOIN RDT.RDTPPA AS RDTPPA WITH (NOLOCK) ON RDTPPA.dropid = PICKDETAIL.dropid 
                            AND RDTPPA.sku = PICKDETAIL.sku
         WHERE PICKDETAIL.OrderKey = @c_orderkey
         AND     PICKDETAIL.DropID  = @c_dropid  
         AND ISNULL(PICKDETAIL.DropID,'') <> '' 
         Group by ISNULL(ORDERS.ExternOrderKey,''),
                  ISNULL(ORDERS.BuyerPO,''),  
                  RDTPPA.lottable04,  
                  RDTPPA.cqty,  
                  ISNULL(ORDERS.DeliveryDate,''),
                  PICKDETAIL.DropID, 
                  PICKDETAIL.Storerkey,   
                  CS.consigneesku,    
                  Storer.Company, 
                  Storer.Fax2, 
                  SKU.descr,
                  RDTPPA.Sku,
                  ORDERS.OrderKey,
                  CASE WHEN ISNULL(CONVERT(FLOAT,CS.CrossSKUQty),0) <> 0 THEN CONVERT(FLOAT,CS.CrossSKUQty) ELSE PACK.casecnt END
         ORDER BY ISNULL(ORDERS.ExternOrderKey,''),PICKDETAIL.DropID, RDTPPA.SKU   
   
   --SELECT * FROM #TEMP_MANIFESTRDT AS tm
        
   DECLARE CUR_RESULT CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
   SELECT DISTINCT rowid,orderkey,dropid,casecnt,sku,tm.storerkey,tm.PPACQTY
   FROM #TEMP_MANIFESTRDT AS tm
   WHERE orderkey = @c_OrderKey AND tm.dropid = @c_dropid
   
   OPEN CUR_RESULT   
     
   FETCH NEXT FROM CUR_RESULT INTO @n_rowid,@c_getorderkey,@c_getdropid ,@n_getcasecnt ,@c_sku ,@c_storerkey,@n_ppacqty 
     
   WHILE @@FETCH_STATUS <> -1  
   BEGIN   


      IF @b_debug  = 1
      BEGIN
         SELECT '@c_orderkey + @c_dropid ' + @c_getorderkey + @c_getdropid,@n_getcasecnt,@c_sku,@c_storerkey
      END 

   SET @n_CurrDropID = 1
   SET @n_CntDropid = 1
   SET @n_TTLPLT = 1
   SET @n_qtypcs = 1
   
   IF @n_getcasecnt = 0 
   BEGIN
       SET @n_casecnt = 0
      
      SELECT @n_casecnt = P.casecnt
      FROM SKU S WITH (NOLOCK)
      JOIN PACK P WITH (NOLOCK) ON P.PackKey=S.PACKKey
      WHERE S.StorerKey = @c_storerkey
      AND S.sku = @c_sku
      
      SET @n_qtypcs = FLOOR(@n_ppacqty/@n_casecnt)
      
   END
   ELSE
   BEGIN
      SET @n_qtypcs = FLOOR(@n_ppacqty/@n_getcasecnt)
   END   
   
   
   IF NOT EXISTS(SELECT 1 FROM #TEMPRDTCTNMANIFEST
                 WHERE Orderkey=@c_OrderKey
                 AND Dropid=@c_getdropid)
   BEGIN
         INSERT INTO #TEMPRDTCTNMANIFEST
          (
            -- RowID -- this column value is auto-generated
            Orderkey,
            Dropid
          )
         SELECT DISTINCT  PD.OrderKey,PD.DropID
         FROM PICKDETAIL PD WITH (NOLOCK)
         WHERE PD.OrderKey = @c_orderkey
         AND PD.Storerkey = @c_storerkey
         AND ISNULL(PD.dropid,'') <> ''
         ORDER BY pd.DropID
   END
      
   SELECT @n_TTLPLT = COUNT(1)
   FROM #TEMPRDTCTNMANIFEST 
   WHERE Orderkey = @c_orderkey
   
   SELECT @n_CurrDropID =RowID
   FROM #TEMPRDTCTNMANIFEST
   WHERE Dropid = @c_getdropid
   AND ISNULL(dropid,'') <> ''

     UPDATE #TEMP_MANIFESTRDT
     SET
      CurrentPLT = @n_CurrDropID,
      TTLPLT = @n_TTLPLT,
      qtypcs = @n_qtypcs
     WHERE dropid = @c_getdropid
     AND Orderkey= @c_getorderkey
     AND sku = @c_sku
     AND Rowid=@n_rowid

       
      FETCH NEXT FROM CUR_RESULT INTO @n_rowid,@c_getorderkey,@c_getdropid ,@n_getcasecnt ,@c_sku ,@c_storerkey,@n_ppacqty 
   END

   Quit:
 SELECT
   tm.ExternOrderkey,
   tm.BuyerPO,
   tm.PPALOTT04,
   tm.PPACQTY,
   tm.deliverdate,
   tm.storerkey,
   tm.sku,
   tm.dropid,
   tm.SDESCR,
   tm.CSKU,
   tm.CASECNT,
   tm.Orderkey,
   tm.STCompany,
   tm.STFAX2,
   tm.CurrentPLT,
   tm.TTLPLT,
   tm.qtypcs
 FROM
   #TEMP_MANIFESTRDT AS tm
 WHERE tm.PPACQTY > 0
 ORDER BY tm.ExternOrderkey, tm.dropid,tm.sku, tm.CSKU

END

 

GO