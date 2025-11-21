SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/        
/* Trigger: ntrPackDetailDelete                                         */        
/* Creation Date:                                                       */        
/* Copyright: IDS                                                       */        
/* Written by:                                                          */        
/*                                                                      */        
/* Purpose:                                                             */        
/*                                                                      */        
/* Usage:                                                               */        
/*                                                                      */        
/* Called By: When records delete from PackDetail                       */        
/*                                                                      */        
/* PVCS Version: 2.3                                                    */        
/*                                                                      */        
/* Version: 5.4                                                         */        
/*                                                                      */        
/* Modifications:                                                       */        
/* Date         Author  Ver.  Purposes                                  */    
/* 2011-May-12  KHLim01 1.1   Insert Delete log                         */
/* 2011-Apr-08  AQSKC   1.2   SOS210154 - Auto Shortpick When ExpQty    */
/*                            Reduced (Kc01)                            */
/* 2011-Jul-14  KHLim02 1.3   GetRight for Delete log                   */
/* 2012-Aug-03  TLTING011.4   Add New Col to DELLOG                     */  
/* 2013-Nov-13  NJOW01  1.5   293687 - Anti Diversity LOR Delete        */
/*                            SerialNo                                  */
/* 2015-Nov-17  NJOW02  1.6   Delete packinfo carton if the carton is   */
/*                            deleted                                   */
/* 2015-Nov-30  NJOW03  1.7   356837-fix delete packdetail update to    */
/*                            packinfo.qty                              */
/* 2017-May-29  Ung     1.8   WMS-1919 Add serial no                    */
/* 2019-Mar-13  Ung     1.9   WMS-8134 Add PackDetailInfo               */
/* 2020-Sep-01  NJOW04  1.10  WMS-15009 - call custom stored proc       */  
/* 2020-AUG-06  Wan01   2.0   WMS-14315 - [CN] NIKE_O2_Ecom Packing_CR  */
/* 2020-SEP-12  NJOW05  2.1   WMS-15001 - reverse serial# when del for  */
/*                            config ADAllowInsertExistingSerialNo and  */
/*                            Option1=NotAllowInsertNewSerialNo         */
/* 2021-Nov-26  Wan02   2.2   WMS-18410 - [RG] Logitech Tote ID Packing */
/*                            Change Request                            */
/* 2021-Nov-26  Wan02   2.2   DevOps Conbine Script                     */
/* 2022-Aug-17  WLChooi 2.3   WMS-20472 - Delete SerialNo (WL01)        */
/* 2023-MAR-29  NJOW06  2.4   WMS-21989 enhance delete/update serialno  */
/*                            condition                                 */
/************************************************************************/        
CREATE   TRIGGER [dbo].[ntrPackDetailDelete] ON [dbo].[PackDetail]      
FOR  DELETE      
AS      
BEGIN      
IF @@ROWCOUNT = 0      
BEGIN      
   RETURN      
END        
          
SET NOCOUNT ON        
SET ANSI_NULLS OFF         
SET QUOTED_IDENTIFIER OFF        
SET CONCAT_NULL_YIELDS_NULL OFF        
          
 DECLARE @b_Success          INT -- Populated by calls to stored procedures - was the proc successful?      
        ,@n_err              INT -- Error number returned by stored procedure or this trigger      
        ,@n_err2             INT -- For Additional Error Detection      
        ,@c_errmsg           NVARCHAR(250) -- Error message returned by stored procedure or this trigger      
        ,@n_continue         INT      
        ,@n_starttcnt        INT -- Holds the current transaction count      
        ,@c_preprocess       NVARCHAR(250) -- preprocess      
        ,@c_pstprocess       NVARCHAR(250) -- post process      
        ,@n_cnt              INT      
        ,@n_PackDetailSysId  INT      
        ,@c_authority        NVARCHAR(1)      
        ,@c_Facility         NVARCHAR(5)      
        ,@c_Storerkey        NVARCHAR(15)      
 
 DECLARE @c_Pickdetailkey     NVARCHAR(10)    --(Kc01)
         ,@n_ShortPackQty     INT            --(Kc01)
         ,@c_GetSkuFromSN_UPC NVARCHAR(30)=''  --NJOW06
       
   DECLARE @n_PackQRFKey      BIGINT         --(Wan01)
         , @cur_PQRF          CURSOR         --(Wan01)

 SELECT @n_continue = 1      
       ,@n_starttcnt = @@TRANCOUNT      
                  
 IF (SELECT COUNT(*) FROM   DELETED) =      
    (SELECT COUNT(*) FROM   DELETED WHERE  DELETED.ArchiveCop = '9')      
 BEGIN      
     SELECT @n_continue = 4      
 END       
   --NJOW04  
   IF @n_continue=1 OR @n_continue=2            
   BEGIN  
      IF EXISTS (SELECT 1 FROM DELETED d    
                 JOIN storerconfig s WITH (NOLOCK) ON  d.storerkey = s.storerkey      
                 JOIN sys.objects sys ON sys.type = 'P' AND sys.name = s.Svalue  
                 WHERE  s.configkey = 'PackdetailTrigger_SP')    
      BEGIN             
         IF OBJECT_ID('tempdb..#INSERTED') IS NOT NULL  
            DROP TABLE #INSERTED  
     
        SELECT *   
        INTO #INSERTED  
        FROM INSERTED  
              
         IF OBJECT_ID('tempdb..#DELETED') IS NOT NULL  
            DROP TABLE #DELETED  
     
        SELECT *   
        INTO #DELETED  
        FROM DELETED  
     
         EXECUTE dbo.isp_PackdetailTrigger_Wrapper  
                   'DELETE'  --@c_Action  
                 , @b_Success  OUTPUT    
                 , @n_Err      OUTPUT     
                 , @c_ErrMsg   OUTPUT    
     
         IF @b_success <> 1    
         BEGIN    
            SELECT @n_continue = 3    
                  ,@c_errmsg = 'ntrPackDetailDelete ' + RTRIM(LTRIM(ISNULL(@c_errmsg,'')))  
         END    
           
         IF OBJECT_ID('tempdb..#INSERTED') IS NOT NULL  
            DROP TABLE #INSERTED  
     
         IF OBJECT_ID('tempdb..#DELETED') IS NOT NULL  
            DROP TABLE #DELETED  
      END  
   END     

   --(Kc01) - start
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN  
        IF EXISTS(SELECT 1 FROM DELETED WHERE Qty > 0 OR ExpQty > 0) 
      BEGIN
         SELECT TOP 1 @c_Storerkey = Storerkey FROM DELETED   
         SELECT @b_success = 0       
         
         EXECUTE nspGetRight NULL, -- facility        
            @c_Storerkey, -- Storerkey        
            NULL, -- Sku        
            'AutoShortPick', -- Configkey        
            @b_success OUTPUT,       
            @c_authority OUTPUT,       
            @n_err OUTPUT,       
            @c_errmsg OUTPUT        
         
         IF @b_success <> 1      
         BEGIN      
             SELECT @n_continue = 3      
                   ,@c_errmsg = 'ntrPackDetailDelete' + dbo.fnc_RTrim(@c_errmsg)      
         END      
         
         IF @c_authority = '1'      
         BEGIN      
             SET @c_Pickdetailkey = ''
             SET @n_ShortPackQty = 0
             SELECT  @n_ShortPackQty = DELETED.ExpQty FROM DELETED
                      
         
             SELECT TOP 1 @c_Pickdetailkey = ISNULL(PK.Pickdetailkey,'')
                FROM DELETED
                JOIN PACKDETAIL PACKD WITH (NOLOCK)
                  ON PACKD.pickslipno = DELETED.pickslipno
                 AND PACKD.cartonno = DELETED.cartonno 
                 AND PACKD.labelno = DELETED.labelno 
                 AND PACKD.labelline = DELETED.labelline 
                 AND PACKD.sku = DELETED.sku
                JOIN PACKHEADER PH WITH (NOLOCK) ON (PACKD.pickslipno = PH.pickslipno AND PH.Status < '9')
                JOIN ORDERDETAIL OD WITH (NOLOCK) ON (PH.orderkey = OD.orderkey AND PACKD.sku = OD.sku AND OD.openqty >= PACKD.expqty)
                JOIN PICKDETAIL PK WITH (NOLOCK) ON (OD.orderkey = PK.orderkey AND OD.orderlinenumber = PK.orderlinenumber AND PK.Status <= '5')
                ORDER BY OD.openqty 
         
             IF @c_Pickdetailkey <> ''
             BEGIN
                UPDATE PICKDETAIL WITH (ROWLOCK)
                SET QTY = QTY - @n_ShortPackQty
                   ,UOMQTY = UOMQTY - @n_ShortPackQty
                WHERE Pickdetailkey = @c_Pickdetailkey
         
                SELECT @n_err = @@ERROR
                IF @n_err <> 0
                BEGIN
                   SELECT @n_continue = 3
                   SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 61811  
                   SELECT @c_errmsg="NSQL"+CONVERT(CHAR(5), @n_err)+": Update Failed On PICKDETAIL. (ntrPackDetailDelete)" + " ( " + " SQLSvr MESSAGE=" + LTRIM(RTRIM(@c_errmsg)) + " ) "
                END
             END          
             ELSE
             BEGIN
                SELECT @n_continue = 3
                SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 61812
                SELECT @c_errmsg="NSQL"+CONVERT(CHAR(5), @n_err)+": Unable To Find Pickdetail to Auto Unallocate. (ntrPackDetailDelete)" 
             END
        END
      END
   END
   --(Kc01) - end
       
-- Serial no
IF @n_continue=1 OR @n_continue=2   
BEGIN
   IF EXISTS( SELECT TOP 1 1 
      FROM DELETED D
         JOIN PackSerialNo PSNO ON (D.PickSlipNo = PSNO.PickSlipNo AND D.CartonNo = PSNO.CartonNo AND D.LabelNo = PSNO.LabelNo AND D.LabelLine = PSNO.LabelLine))
   BEGIN
      DECLARE @n_PackSerialNoKey BIGINT
      DECLARE @curPSNO CURSOR
      SET @curPSNO = CURSOR FOR
         SELECT PSNO.PackSerialNoKey
         FROM DELETED D
            JOIN PackSerialNo PSNO ON (D.PickSlipNo = PSNO.PickSlipNo AND D.CartonNo = PSNO.CartonNo AND D.LabelNo = PSNO.LabelNo AND D.LabelLine = PSNO.LabelLine)
         ORDER BY PSNO.PackSerialNoKey
      OPEN @curPSNO      
      FETCH NEXT FROM @curPSNO INTO @n_PackSerialNoKey    
      WHILE @@FETCH_STATUS = 0 
      BEGIN
         DELETE PackSerialNo WHERE PackSerialNoKey = @n_PackSerialNoKey
         SELECT @n_err = @@ERROR      
         IF @n_err <> 0      
         BEGIN      
            SELECT @n_continue = 3      
            SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 61813
            SELECT @c_errmsg='NSQL'+CONVERT(CHAR(6), @n_err)+': Delete Failed On Table PackSerialNo. (ntrPackDetailDelete)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg), '') + ' ) '      
            BREAK
         END  
         FETCH NEXT FROM @curPSNO INTO @n_PackSerialNoKey
      END
   END
END

-- PackDetailInfo
IF @n_continue=1 OR @n_continue=2   
BEGIN
   IF EXISTS( SELECT TOP 1 1 
      FROM DELETED D
         JOIN PackDetailInfo PDInfo ON (D.PickSlipNo = PDInfo.PickSlipNo AND D.CartonNo = PDInfo.CartonNo AND D.LabelNo = PDInfo.LabelNo AND D.LabelLine = PDInfo.LabelLine))
   BEGIN
      DECLARE @n_PackDetailInfoKey BIGINT
      DECLARE @curPDInfo CURSOR
      SET @curPDInfo = CURSOR FOR
         SELECT PDInfo.PackDetailInfoKey
         FROM DELETED D
            JOIN PackDetailInfo PDInfo ON (D.PickSlipNo = PDInfo.PickSlipNo AND D.CartonNo = PDInfo.CartonNo AND D.LabelNo = PDInfo.LabelNo AND D.LabelLine = PDInfo.LabelLine)
         ORDER BY PDInfo.PackDetailInfoKey
      OPEN @curPDInfo      
      FETCH NEXT FROM @curPDInfo INTO @n_PackDetailInfoKey    
      WHILE @@FETCH_STATUS = 0 
      BEGIN
         DELETE PackDetailInfo WHERE PackDetailInfoKey = @n_PackDetailInfoKey
         SELECT @n_err = @@ERROR      
         IF @n_err <> 0      
         BEGIN      
            SELECT @n_continue = 3      
            SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 61818
            SELECT @c_errmsg='NSQL'+CONVERT(CHAR(6), @n_err)+': Delete Failed On Table PackDetailInfo. (ntrPackDetailDelete)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg), '') + ' ) '      
            BREAK
         END  
         FETCH NEXT FROM @curPDInfo INTO @n_PackDetailInfoKey
      END
   END
END

--(Wan01) - START PackQRF
IF @n_continue=1 OR @n_continue=2   
BEGIN
   IF EXISTS(  SELECT TOP 1 1 
               FROM DELETED D
               JOIN PackQRF PQRF ON D.PickSlipNo = PQRF.PickSlipNo
                                AND D.CartonNo  = PQRF.CartonNo 
                                AND D.LabelLine = PQRF.LabelLine
            )
   BEGIN
      SET @cur_PQRF = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR   
      SELECT PQRF.PackQRFKey
      FROM DELETED D
      JOIN PackQRF PQRF ON D.PickSlipNo = PQRF.PickSlipNo 
                        AND D.CartonNo  = PQRF.CartonNo 
                        AND D.LabelLine = PQRF.LabelLine
      ORDER BY PQRF.PackQRFKey

      OPEN @cur_PQRF  
          
      FETCH NEXT FROM @cur_PQRF INTO @n_PackQRFKey  
        
      WHILE @@FETCH_STATUS = 0 
      BEGIN
         DELETE PackQRF WHERE PackQRFKey = @n_PackQRFKey

         SET @n_err = @@ERROR      
         
         IF @n_err <> 0      
         BEGIN      
            SET @n_continue = 3      
            SET @c_errmsg = CONVERT(char(250),@n_err)
            SET @n_err = 61819
            SET @c_errmsg='NSQL'+CONVERT(char(6), @n_err)+': Delete Failed On Table PackQRF. (ntrPackDetailDelete)' 
                         + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg), '') + ' ) '      
            BREAK
         END  
         FETCH NEXT FROM @cur_PQRF INTO @n_PackQRFKey
      END
      CLOSE @cur_PQRF
      DEALLOCATE @cur_PQRF
   END
END
--(Wan01) - END PackQRF

 IF @n_continue=1 OR @n_continue=2   
 BEGIN      
     SELECT TOP 1 @c_Storerkey = Storerkey FROM DELETED   
     SELECT @b_success = 0       
     EXECUTE nspGetRight NULL, -- facility        
     @c_Storerkey, -- Storerkey        
     NULL, -- Sku        
     'AutoDelPHeader', -- Configkey        
     @b_success OUTPUT,       
     @c_authority OUTPUT,       
     @n_err OUTPUT,       
     @c_errmsg OUTPUT        
     IF @b_success <> 1      
     BEGIN      
         SELECT @n_continue = 3      
               ,@c_errmsg = 'ntrPackDetailDelete' + dbo.fnc_RTrim(@c_errmsg)      
     END      
  
     IF @c_authority = '1'      
     BEGIN      
       IF EXISTS ( SELECT 1   
                   FROM PackHeader with (NOLOCK)  
                        JOIN DELETED on DELETED.PickSlipNo = PackHeader.PickSlipNo  
                   WHERE NOT EXISTS ( SELECT 1 FROM PackDetail with (NOLOCK)  
                                      WHERE PackDetail.PickSlipNo = PackHeader.PickSlipNo ) )  
       BEGIN  
          DELETE PackHeader   
          FROM PackHeader   
               JOIN DELETED on DELETED.PickSlipNo = PackHeader.PickSlipNo  
          WHERE NOT EXISTS ( SELECT 1 FROM PackDetail (NOLOCK)  
                             WHERE PackDetail.PickSlipNo = PackHeader.PickSlipNo )  
          SELECT @n_err = @@ERROR,@n_cnt = @@ROWCOUNT    
          IF @n_err <> 0  
          BEGIN      
              SELECT @n_continue = 3      
                    ,@n_err = 61814        
              SELECT @c_errmsg = "NSQL"+CONVERT(CHAR(5) ,@n_err)+      
               ": Deletion of PackHeader not allowed. (ntrPackDetailDelete)"      
          END  
       END  
     END   -- END StorerConfig   
 END  
       
   -- Start (KHLim01) 
   IF @n_continue = 1 or @n_continue = 2
   BEGIN
      SELECT @b_success = 0         --    Start (KHLim02)
      EXECUTE nspGetRight  NULL,             -- facility  
                           NULL,             -- Storerkey  
                           NULL,             -- Sku  
                           'DataMartDELLOG', -- Configkey  
                           @b_success     OUTPUT, 
                           @c_authority   OUTPUT, 
                           @n_err         OUTPUT, 
                           @c_errmsg      OUTPUT  
      IF @b_success <> 1
      BEGIN
         SELECT @n_continue = 3
               ,@c_errmsg = 'ntrPackDetailDelete' + dbo.fnc_RTrim(@c_errmsg)
      END
      ELSE 
      IF @c_authority = '1'         --    End   (KHLim02)
      BEGIN
            -- tlting01  
         INSERT INTO dbo.PackDetail_DELLOG ( PickSlipNo, CartonNo, LabelNo, LabelLine, Storerkey, SKU, QTY )     
         SELECT PickSlipNo, CartonNo, LabelNo, LabelLine, Storerkey, SKU, QTY FROM DELETED  
         SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
         IF @n_err <> 0
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 61815
            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Delete Trigger On Table PackDetail Failed. (ntrPackDetailDelete)' + ' ( ' + ' SQLSvr MESSAGE=' + LTrim(RTrim(@c_errmsg)) + ' ) '
         END
      END
   END
   -- End (KHLim01) 

 --NJOW01
 IF @n_continue = 1 or @n_continue = 2
 BEGIN
 	  --NJOW06
    SELECT TOP 1 @c_Storerkey = Storerkey FROM DELETED   
    SELECT @c_GetSkuFromSN_UPC = dbo.fnc_GetRight('', @c_Storerkey, '', 'GetSkuFromSN_UPC')  	
    
    IF @c_GetSkuFromSN_UPC = '1' --NJOW06
    BEGIN
       DELETE SerialNo 
       FROM SerialNo
       JOIN PACKHEADER PH (NOLOCK) ON SerialNo.Orderkey = PH.Orderkey AND SerialNo.Storerkey = PH.Storerkey 
                                 AND (SerialNo.Pickslipno = PH.Pickslipno OR ISNULL(Serialno.Pickslipno,'')='')   --WL01                       
       LEFT JOIN UPC (NOLOCK) ON SERIALNO.UserDefine02 = UPC.Upc AND SERIALNO.Storerkey = UPC.Storerkey                                                                                                --                  	                                                                   
       JOIN DELETED ON PH.PickslipNo = DELETED.PickslipNo
                      AND (SerialNo.Sku = DELETED.Sku OR UPC.Sku = DELETED.Sku)
                      AND SerialNo.OrderLineNumber = LTRIM(CAST(DELETED.Cartonno AS NVARCHAR(5)))           
                      AND (SerialNo.LabelLine = DELETED.LabelLine OR ISNULL(SerialNo.LabelLine,'')='')   --WL01
       JOIN SKU (NOLOCK) ON DELETED.Storerkey = SKU.Storerkey AND DELETED.Sku = SKU.Sku
       LEFT JOIN STORERCONFIG SC (NOLOCK) ON PH.Storerkey = SC.Storerkey AND SC.Configkey = 'ADAllowInsertExistingSerialNo' AND SC.Option1 = 'NotAllowInsertNewSerialNo' AND SC.Svalue = '1' --NJOW05
       WHERE (SKU.Susr4 = 'AD' OR SKU.SerialNoCapture IN('1','3'))  --NJOW06
       AND SC.SValue IS NULL  --NJOW05
    END
    ELSE
    BEGIN
       DELETE SerialNo 
       FROM SerialNo
       JOIN PACKHEADER PH (NOLOCK) ON SerialNo.Orderkey = PH.Orderkey AND SerialNo.Storerkey = PH.Storerkey 
                                 AND (SerialNo.Pickslipno = PH.Pickslipno OR ISNULL(Serialno.Pickslipno,'')='')   --WL01
       JOIN DELETED ON PH.PickslipNo = DELETED.PickslipNo
                      AND SerialNo.Sku = DELETED.Sku 
                      AND SerialNo.OrderLineNumber = LTRIM(CAST(DELETED.Cartonno AS NVARCHAR(5)))           
                      AND (SerialNo.LabelLine = DELETED.LabelLine OR ISNULL(SerialNo.LabelLine,'')='')   --WL01
       JOIN SKU (NOLOCK) ON DELETED.Storerkey = SKU.Storerkey AND DELETED.Sku = SKU.Sku
       LEFT JOIN STORERCONFIG SC (NOLOCK) ON PH.Storerkey = SC.Storerkey AND SC.Configkey = 'ADAllowInsertExistingSerialNo' AND SC.Option1 = 'NotAllowInsertNewSerialNo' AND SC.Svalue = '1' --NJOW05
       WHERE (SKU.Susr4 = 'AD' OR SKU.SerialNoCapture IN('1','3'))  --NJOW06
       AND SC.SValue IS NULL  --NJOW05
    END

    SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
    IF @n_err <> 0
    BEGIN
       SELECT @n_continue = 3
       SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 61816
       SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Delete Trigger On Table PackDetail Failed. (ntrPackDetailDelete)' + ' ( ' + ' SQLSvr MESSAGE=' + LTrim(RTrim(@c_errmsg)) + ' ) '
    END        
    
    IF @c_GetSkuFromSN_UPC = '1' --NJOW06
    BEGIN
       --NJOW05
       UPDATE SERIALNO WITH (ROWLOCK)
       SET SERIALNO.Orderkey = '',
           SERIALNO.OrderLineNumber = '',
           SERIALNO.Status = '1',        
           SERIALNO.Trafficcop = NULL,
           SERIALNO.Pickslipno = '',  --NJOW06
           SERIALNO.CartonNo = 0,  --NJOW06
           SERIALNO.LabelLine = '' --NJOW06
       FROM SERIALNO 
       JOIN PACKHEADER PH (NOLOCK) ON SerialNo.Orderkey = PH.Orderkey AND SerialNo.Storerkey = PH.Storerkey 
                                  AND (SerialNo.Pickslipno = PH.Pickslipno OR ISNULL(Serialno.Pickslipno,'')='')   --WL01
       LEFT JOIN UPC (NOLOCK) ON SERIALNO.UserDefine02 = UPC.Upc AND SERIALNO.Storerkey = UPC.Storerkey                 	                                                                                                     
       JOIN DELETED ON PH.PickslipNo = DELETED.PickslipNo
                       AND (SerialNo.Sku = DELETED.Sku OR UPC.Sku = DELETED.Sku)
                       AND SerialNo.OrderLineNumber = LTRIM(CAST(DELETED.Cartonno AS NVARCHAR(5))) 
                       AND (SerialNo.LabelLine = DELETED.LabelLine OR ISNULL(SerialNo.LabelLine,'')='')   --WL01
       JOIN SKU (NOLOCK) ON DELETED.Storerkey = SKU.Storerkey AND DELETED.Sku = SKU.Sku
       JOIN STORERCONFIG SC (NOLOCK) ON PH.Storerkey = SC.Storerkey AND SC.Configkey = 'ADAllowInsertExistingSerialNo' AND SC.Option1 = 'NotAllowInsertNewSerialNo' AND SC.Svalue = '1' --Fix
       WHERE (SKU.Susr4 = 'AD' OR SKU.SerialNoCapture IN('1','3')) --NJOW06
    END
    ELSE
    BEGIN
       --NJOW05
       UPDATE SERIALNO WITH (ROWLOCK)
       SET SERIALNO.Orderkey = '',
           SERIALNO.OrderLineNumber = '',
           SERIALNO.Status = '1',        
           SERIALNO.Trafficcop = NULL,
           SERIALNO.Pickslipno = '',  --NJOW06
           SERIALNO.CartonNo = 0,  --NJOW06
           SERIALNO.LabelLine = '' --NJOW06
       FROM SERIALNO 
       JOIN PACKHEADER PH (NOLOCK) ON SerialNo.Orderkey = PH.Orderkey AND SerialNo.Storerkey = PH.Storerkey 
                                  AND (SerialNo.Pickslipno = PH.Pickslipno OR ISNULL(Serialno.Pickslipno,'')='')   --WL01
       JOIN DELETED ON PH.PickslipNo = DELETED.PickslipNo
                       AND SerialNo.Sku = DELETED.Sku 
                       AND SerialNo.OrderLineNumber = LTRIM(CAST(DELETED.Cartonno AS NVARCHAR(5))) 
                       AND (SerialNo.LabelLine = DELETED.LabelLine OR ISNULL(SerialNo.LabelLine,'')='')   --WL01
       JOIN SKU (NOLOCK) ON DELETED.Storerkey = SKU.Storerkey AND DELETED.Sku = SKU.Sku
       JOIN STORERCONFIG SC (NOLOCK) ON PH.Storerkey = SC.Storerkey AND SC.Configkey = 'ADAllowInsertExistingSerialNo' AND SC.Option1 = 'NotAllowInsertNewSerialNo' AND SC.Svalue = '1' --Fix
       WHERE (SKU.Susr4 = 'AD' OR SKU.SerialNoCapture IN('1','3')) --NJOW06
    END
    

    SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
    IF @n_err <> 0
    BEGIN
       SELECT @n_continue = 3
       SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 61817
       SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Delete Trigger On Table PackDetail Failed. (ntrPackDetailDelete)' + ' ( ' + ' SQLSvr MESSAGE=' + LTrim(RTrim(@c_errmsg)) + ' ) '
    END             
 END     
  
--(Wan02) - START
IF @n_continue = 1 or @n_continue = 2
BEGIN
   ;WITH pdl AS
    ( SELECT PACKDETAILLABEL.RowID
      FROM PACKDETAILLABEL WITH (NOLOCK)
      JOIN DELETED ON PACKDETAILLABEL.Pickslipno = DELETED.Pickslipno AND PACKDETAILLABEL.labelNo = DELETED.labelNo
      LEFT JOIN PACKDETAIL (NOLOCK) ON PACKDETAILLABEL.Pickslipno = PACKDETAIL.Pickslipno AND PACKDETAILLABEL.labelNo = PACKDETAIL.labelNo
      WHERE PACKDETAIL.labelNo IS NULL
    )
   DELETE p WITH (ROWLOCK)
   FROM pdl
   JOIN PACKDETAILLABEL p ON p.RowID = pdl.RowID

   SET @n_err = @@ERROR
   IF @n_err <> 0
   BEGIN
      SELECT @n_continue = 3
      SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 61817
      SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Delete Trigger On Table PACKDETAILLABEL Failed. (ntrPackDetailDelete)' + ' ( ' + ' SQLSvr MESSAGE=' + LTrim(RTrim(@c_errmsg)) + ' ) '
   END
END
--(Wan02) - END
 
 --NJOW02
 IF @n_continue = 1 or @n_continue = 2
 BEGIN
     DELETE PACKINFO
     FROM PACKINFO
     JOIN DELETED ON PACKINFO.Pickslipno = DELETED.Pickslipno AND PACKINFO.Cartonno = DELETED.Cartonno
     LEFT JOIN PACKDETAIL (NOLOCK) ON PACKINFO.Pickslipno = PACKDETAIL.Pickslipno AND PACKINFO.Cartonno = PACKDETAIL.Cartonno
     WHERE PACKDETAIL.Cartonno IS NULL

    SELECT @n_err = @@ERROR
    IF @n_err <> 0
    BEGIN
       SELECT @n_continue = 3
       SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 61817
       SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Delete Trigger On Table PackInfo Failed. (ntrPackDetailDelete)' + ' ( ' + ' SQLSvr MESSAGE=' + LTrim(RTrim(@c_errmsg)) + ' ) '
    END
 END

 --NJOW03
 IF @n_continue = 1 or @n_continue = 2
 BEGIN
    UPDATE PACKINFO WITH (ROWLOCK)
    SET PACKINFO.Qty = PACKINFO.Qty - DELETED.Qty
    FROM DELETED
    JOIN PACKINFO ON DELETED.Pickslipno = PACKINFO.Pickslipno
                  AND DELETED.CartonNo = PACKINFO.CartonNo                         

     IF EXISTS(SELECT 1
               FROM DELETED
               JOIN STORERCONFIG (NOLOCK) ON DELETED.StorerKey = STORERCONFIG.StorerKey     
                                         AND STORERCONFIG.ConfigKey = 'Default_PackInfo' AND STORERCONFIG.SValue='1')
    BEGIN
       UPDATE PACKINFO WITH (ROWLOCK)
       SET PACKINFO.Weight = PACKINFO.Weight - (DELETED.Qty * Sku.StdGrossWgt),
           PACKINFO.Cube = PACKINFO.Cube - CASE WHEN ISNULL(CZ.Cube,0) = 0 THEN DELETED.Qty * Sku.StdCube ELSE 0 END
       FROM DELETED 
       JOIN PACKINFO ON DELETED.Pickslipno = PACKINFO.Pickslipno
                     AND DELETED.CartonNo = PACKINFO.CartonNo                         
       JOIN STORERCONFIG (NOLOCK) ON DELETED.StorerKey = STORERCONFIG.StorerKey     
                                   AND STORERCONFIG.ConfigKey = 'Default_PackInfo' AND STORERCONFIG.SValue='1'
         JOIN STORER (NOLOCK) ON (DELETED.StorerKey = STORER.StorerKey)
       JOIN SKU (NOLOCK) ON (DELETED.Storerkey = SKU.Storerkey AND DELETED.SKU = SKU.Sku)
         LEFT JOIN CARTONIZATION CZ (NOLOCK) ON (STORER.CartonGroup = CZ.CartonizationGroup AND CZ.CartonType = PACKINFO.CartonType) 
    END
 END 
 
 IF @n_continue=3 -- Error Occured - Process And Return      
 BEGIN      
     IF @@TRANCOUNT = 1      
     AND @@TRANCOUNT >= @n_starttcnt      
     BEGIN      
         ROLLBACK TRAN      
     END      
     ELSE      
     BEGIN      
         WHILE @@TRANCOUNT > @n_starttcnt      
         BEGIN      
             COMMIT TRAN      
         END      
     END       
     EXECUTE nsp_logerror @n_err, @c_errmsg, "ntrPackDetailDelete"       
     RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012       
     RETURN      
 END      
 ELSE      
 BEGIN      
     WHILE @@TRANCOUNT > @n_starttcnt      
     BEGIN      
         COMMIT TRAN      
     END       
     RETURN      
 END      
END 


GO