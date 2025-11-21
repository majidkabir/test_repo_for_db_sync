SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Store Procedure:  nsp_SkuLabelTote01                                 */  
/* Creation Date: 29-Jun-2010                                           */  
/* Copyright: IDS                                                       */  
/* Written by: Vanessa                                                  */  
/*                                                                      */  
/* Purpose:  SOS#177739 Project Diana - Kimball Label - GBP             */  
/*                                                                      */  
/* Input Parameters:  @c_DropID , - DropID                              */  
/*                                                                      */  
/* Called By:  dw = r_dw_sku_label_tote01                               */  
/*                                                                      */  
/* PVCS Version: 1.2                                                    */  
/*                                                                      */  
/* Version: 5.4                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author        Purposes                                  */  
/* 25-11-2010   James         Only print when totes is not ship/canc    */  
/*                            (james01)                                 */
/* 17-AUG-2012  YTWan   1.2   SOS#253220:kimball Label EAN13 (German    */
/*                            Stores) - (Wan02)                         */
/* 27-Feb-2017  TLTING  1.3   Variable Nvarchar                         */
/************************************************************************/  
  
CREATE PROC [dbo].[nsp_SkuLabelTote01] (  
   @c_DropID NVARCHAR(18)  
)   
AS  
BEGIN  
   SET NOCOUNT ON  
   SET ANSI_NULLS OFF  
   SET QUOTED_IDENTIFIER OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE @n_continue         int,  
    @c_errmsg         char(255),  
    @b_success         int,  
    @n_err          int,  
  @n_starttcnt          int  
  
   --(Wan01)- START
   DECLARE @c_StorerKey     NVARCHAR(15) 
         , @c_SKU           NVARCHAR(20) 
         , @n_QTY           INT 
         , @n_Count         INT                                                       

   CREATE TABLE #TEMPLABEL (
           DropID		         NVARCHAR(18)
         , Sku                NVARCHAR(20)
         , Descr              NVARCHAR(60) 
         , SkuGroup           NVARCHAR(10)
         , Style              NVARCHAR(20)
         , Color              NVARCHAR(20)         
         , Size               NVARCHAR(5)          
         , Busr9              NVARCHAR(30)
         , Price              DECIMAL(12,2)
         , Cost               DECIMAL(12,2)  
         )   

   --DECLARE @c_StorerKey     VARCHAR(15),  
   --        @c_SKU           VARCHAR(20),  
   --        @n_QTY           INT,  
   --        @n_Count         INT  
  
   --CREATE TABLE #TEMPLABEL (  
   --DropID     VARCHAR(18),  
   --      SKU            VARCHAR(20),  
   --      DESCR          VARCHAR(60),            
   --      SKUSize        VARCHAR(5),            
   --      Price          DECIMAL(12,2))  
   --(Wan01)- END
   SELECT @n_continue = 1, @n_starttcnt = @@TRANCOUNT   
  
   BEGIN TRAN  
  
   --(Wan01)- START
   --INSERT INTO #TEMPLABEL   
   --   (DropID, SKU, DESCR, SKUSize, Price)  
   --VALUES  
   --   ('TOTE:', '', '', '', 0.00)  
  
   --INSERT INTO #TEMPLABEL   
   --   (DropID, SKU, DESCR, SKUSize, Price)  
   --VALUES  
   --   (@c_DropID, '', '', '', 0.00) 

   INSERT INTO #TEMPLABEL 
                  (DropID, Sku, Descr, SkuGroup, Style, Color, Size, Busr9, Price, Cost)
   VALUES ('TOTE:','','','','','','','',0.00,0.00)

   INSERT INTO #TEMPLABEL 
                  (DropID, Sku, Descr, SkuGroup, Style, Color, Size, Busr9, Price, Cost)
   VALUES (@c_DropID,'','','','','','','',0.00,0.00)
 
   --(Wan01)- END
  
   SELECT @n_err = @@ERROR  
   IF @n_err <> 0  
   BEGIN  
      SELECT @n_continue = 3  
      SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 63104     
    SELECT @c_errmsg = 'NSQL'+CONVERT(char(5),@n_err)+': Insert #TEMPLABEL Failed. ' +   
                         ' (nsp_SkuLabelTote01)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '  
      GOTO EXIT_SP  
   END  
  
--   (james01)
--   DECLARE C_PackDetail CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
--   SELECT PackDetail.StorerKey, PackDetail.Sku, PackDetail.QTY  
--   FROM PackDetail (NOLOCK)  
--   WHERE PackDetail.DropID = @c_DropID  
   DECLARE C_PackDetail CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
   SELECT PackDetail.StorerKey, PackDetail.Sku, PackDetail.QTY  
	FROM Orders Orders WITH (NOLOCK) 
   JOIN PACKHEADER PACKHEADER WITH (NOLOCK) 
      ON (Orders.Storerkey = PACKHEADER.Storerkey AND Orders.OrderKey  = PACKHEADER.OrderKey) 
   JOIN PACKDETAIL PACKDETAIL WITH (NOLOCK) ON (PACKHEADER.PICKSLIPNO = PACKDETAIL.PICKSLIPNO) 
   JOIN DROPID DROPID WITH (NOLOCK) ON (PACKDETAIL.DROPID = DROPID.DROPID AND DROPID.LOADKEY = ORDERS.LOADKEY) 
   WHERE PACKDETAIL.DropID = @c_DropID 
      AND ORDERS.Status NOT IN ('CANC','9') 

   OPEN C_PackDetail  
   FETCH NEXT FROM C_PackDetail INTO @c_StorerKey, @c_SKU, @n_QTY    
   WHILE (@@FETCH_STATUS <> -1)  
   BEGIN  
      SET @n_Count = 1  
  
      WHILE @n_Count <= @n_QTY  
      BEGIN  
         --(Wan01) -START
         --INSERT INTO #TEMPLABEL   
         --   (DropID, SKU, DESCR, SKUSize, Price)  
         --SELECT '',  
         --       Sku,     
         --       DESCR,  
         --       Size,   
         --   Price  
         --FROM SKU (NOLOCK)  
         --WHERE StorerKey = @c_StorerKey  
         --AND SKU = @c_SKU 
 
         INSERT INTO #TEMPLABEL 
                  (DropID, Sku, Descr, SkuGroup, Style, Color, Size, Busr9, Price, Cost)
         SELECT ''
               ,ISNULL(RTRIM(Sku),'') 
               ,ISNULL(SUBSTRING(RTRIM(Descr),1,20),'') 
               ,ISNULL(RTRIM(SkuGroup),'') 
               ,ISNULL(SUBSTRING(RTRIM(Style),1,9),'') 
               ,ISNULL(RTRIM(Color),'') 
               ,ISNULL(RTRIM(Size),'')
               ,ISNULL(RTRIM(Busr9),'')   
               ,ISNULL(Price,0.00)
               ,ISNULL(Cost,0.00)
            FROM SKU WITH (NOLOCK) 
            WHERE StorerKey = @c_StorerKey
            AND SKU = @c_SKU 
         --(Wan01) -END
  
         WHILE @@TRANCOUNT > @n_starttcnt  
            COMMIT TRAN  
  
         SET @n_Count = @n_Count + 1  
      END  
  
      FETCH NEXT FROM C_PackDetail INTO @c_StorerKey, @c_SKU, @n_QTY   
   END --end of while  
   CLOSE C_PackDetail  
   DEALLOCATE C_PackDetail  
     -- Retrieve values  

   --(Wan01) - START
   --SELECT DropID, UPPER(SKU), RTRIM(LTRIM(DESCR)), SKUSize, Price  
   --FROM #TEMPLABEL  
   SELECT DropID
         ,Sku
         ,Descr
         ,SkuGroup
         ,Style
         ,Color
         ,Size
         ,Busr9
         ,Price
         ,Cost
   FROM #TEMPLABEL
   --(Wan01) - END

   DROP TABLE #TEMPLABEL  
  
   EXIT_SP:   
   IF @n_continue = 3  
   BEGIN  
      WHILE @@TRANCOUNT > @n_starttcnt  
      ROLLBACK TRAN  
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'nsp_SkuLabelTote01'  
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012  
      RETURN  
   END  
   ELSE  
   BEGIN  
      /* Error Did Not Occur , Return Normally */  
      WHILE @@TRANCOUNT > @n_starttcnt  
         COMMIT TRAN  
      RETURN  
   END  
  
END

GO