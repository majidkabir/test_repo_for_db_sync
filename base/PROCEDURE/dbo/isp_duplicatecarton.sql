SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: isp_DuplicateCarton                                */
/* Creation Date: 06-Jan-2015                                           */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: 320446 - Duplicate packing carton                           */
/*                                                                      */
/* Called By:                                                           */ 
/*                                                                      */
/* Parameters:                                                          */
/*                                                                      */
/* PVCS Version: 1.2                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author Ver.  Purposes                                    */
/* 13-MAY-2016 Wan01  1.1   Specify SP parameters                       */  
/* 11-MAR-2021 Wan02  1.2   WMS-16026 - PB-Standardize TrackingNo       */
/* 19-Jul-2021 NJOW01 1.3   WMS-17491 copy lottablevalue column and     */
/*                          validation                                  */
/************************************************************************/

CREATE PROC [dbo].[isp_DuplicateCarton]
         @c_PickSlipNo       NVARCHAR(10),
         @n_FromCartonNo     INT,
         @n_ToNumberOfCarton INT = 1,
         @n_NewCartonNoFrom  INT OUTPUT,
         @n_NewCartonNoTo    INT OUTPUT,
         @b_Success          INT       OUTPUT,
         @n_err              INT       OUTPUT,
         @c_errmsg           NVARCHAR(2000) OUTPUT  --NJOW01
AS
BEGIN
   SET NOCOUNT ON   
   SET ANSI_NULLS OFF  
   SET QUOTED_IDENTIFIER OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF  
   
   DECLARE @n_starttcnt INT,
           @n_continue INT,
           @n_cnt INT,
           @n_NewCartonNo INT,
           @c_NewLabelNo NVARCHAR(20),           
           @c_isConsoPack NVARCHAR(5),
           @c_PackByLottable NVARCHAR(30),
           @c_SPCode NVARCHAR(30),
           @c_Storerkey NVARCHAR(15),
           @c_Sku NVARCHAR(20), 
           @c_LottableValue NVARCHAR(60), 
           @n_PackingQty INT,
           @c_Facility NVARCHAR(5),
           @c_SQL NVARCHAR(4000),
           @c_ErrMsg2 NVARCHAR(250)  --NJOW01
   
   SELECT @n_starttcnt=@@TRANCOUNT, @n_continue=1, @b_success=0, @n_err=0, @c_errmsg='', @n_cnt = 0, @n_NewCartonNo = 0, @c_ErrMsg2 = '' 
   
   IF EXISTS (SELECT 1
              FROM PACKHEADER (NOLOCK)
              WHERE Pickslipno = @c_Pickslipno
              AND ISNULL(PACKHEADER.Orderkey,'') <> '')  
   BEGIN   	 
        IF EXISTS ( SELECT 1 FROM
                      (SELECT PKD.Storerkey, PKD.Sku, SUM(PD.Qty) AS PickedQty,
                              ISNULL((SELECT SUM(PACKDETAIL.Qty)   
                                       FROM PACKDETAIL(NOLOCK)   
                                       WHERE PACKDETAIL.PickSlipNo = PKH.Pickslipno   
                                       AND PACKDETAIL.Storerkey = PKD.Storerkey     
                                       AND PACKDETAIL.SKU = PKD.SKU), 0) AS PackedQty,
                               PKD.Qty AS QtyPerCarton   
                     FROM PACKHEADER PKH (NOLOCK)
                     JOIN PACKDETAIL PKD (NOLOCK) ON PKH.Pickslipno = PKD.Pickslipno
                     JOIN PICKDETAIL PD (NOLOCK) ON PKD.Storerkey = PD.Storerkey AND PKD.Sku = PD.Sku AND PKH.Orderkey = PD.Orderkey
                     WHERE PKH.Pickslipno = @c_Pickslipno
                     AND PKD.CartonNo = @n_FromCartonNo
                     GROUP BY PKH.Pickslipno, PKD.Storerkey, PKD.Sku, PKD.Qty) AS T 
                  WHERE T.PickedQty < (T.PackedQty + (T.QtyPerCarton * @n_ToNumberOfCarton)) )        
      BEGIN
         SELECT @n_continue = 3 
         SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=61900   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Pack qty to duplicate exceeded pickded qty. (isp_DuplicateCarton)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(ISNULL(@c_errmsg,'')) + ' ) '
      END
      SET @c_isConsoPack = 'N'
   END
   ELSE
   BEGIN
        IF EXISTS ( SELECT 1 FROM
                       (SELECT PKD.Storerkey, PKD.Sku, SUM(PD.Qty) AS PickedQty,
                               ISNULL((SELECT SUM(PACKDETAIL.Qty)   
                                        FROM PACKDETAIL(NOLOCK)   
                                        WHERE PACKDETAIL.PickSlipNo = PKH.Pickslipno   
                                        AND PACKDETAIL.Storerkey = PKD.Storerkey     
                                        AND PACKDETAIL.SKU = PKD.SKU), 0) AS PackedQty,
                             PKD.Qty AS QtyPerCarton                             
                        FROM PACKHEADER PKH (NOLOCK)
                      JOIN PACKDETAIL PKD (NOLOCK) ON PKH.Pickslipno = PKD.Pickslipno
                      JOIN LOADPLANDETAIL LPD (NOLOCK) ON PKH.LoadKey = LPD.LoadKey
                      JOIN PICKDETAIL PD (NOLOCK) ON PKD.Storerkey = PD.Storerkey AND PKD.Sku = PD.Sku AND LPD.Orderkey = PD.Orderkey
                      WHERE PKH.Pickslipno = @c_Pickslipno
                      AND PKD.CartonNo = @n_FromCartonNo
                      GROUP BY PKH.Pickslipno, PKD.Storerkey, PKD.Sku, PKD.Qty) AS T  
                  WHERE T.PickedQty < (T.PackedQty + (T.QtyPerCarton * @n_ToNumberOfCarton)) )        
      BEGIN
         SELECT @n_continue = 3 
         SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=61910   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Pack qty to duplicate exceeded pickded qty. (isp_DuplicateCarton)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(ISNULL(@c_errmsg,'')) + ' ) '
      END
      SET @c_isConsoPack = 'Y'
   END
   
   --NJOW01
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
   	  IF @c_isConsoPack = 'N'
   	  BEGIN
         SELECT @c_Storerkey = O.Storerkey,
                @c_Facility = O.Facility             
         FROM PACKHEADER PH (NOLOCK)
         JOIN ORDERS O (NOLOCK) ON PH.Orderkey = O.Orderkey
         WHERE PH.Pickslipno = @c_Pickslipno
      END
      ELSE
      BEGIN
         SELECT TOP 1 @c_Storerkey = O.Storerkey,
                      @c_Facility = O.Facility             
         FROM PACKHEADER PH (NOLOCK)
         JOIN LOADPLANDETAIL LPD (NOLOCK) ON PH.LoadKey = LPD.LoadKey         
         JOIN ORDERS O (NOLOCK) ON LPD.Orderkey = O.Orderkey
         WHERE PH.Pickslipno = @c_Pickslipno
      END            
      
      SELECT @c_PackByLottable = dbo.fnc_GetRight(@c_Facility, @c_Storerkey, '', 'PackByLottable') 
      SELECT @c_SPCode = dbo.fnc_GetRight(@c_Facility, @c_Storerkey, '', 'PackByLottableValidate_SP') 
         
      IF @c_PackByLottable = '1' AND EXISTS (SELECT 1 FROM dbo.sysobjects WHERE name = RTRIM(@c_SPCode) AND type = 'P')
      BEGIN      	
         DECLARE CUR_CARTON CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT Sku, LottableValue, SUM(Qty) * @n_ToNumberOfCarton
            FROM PACKDETAIL (NOLOCK)
            WHERE Pickslipno = @c_Pickslipno
            AND CartonNo = @n_FromCartonNo
            AND LottableValue <> ''
            AND LottableValue IS NOT NULL
            GROUP BY Sku, LottableValue

         OPEN CUR_CARTON
         
         FETCH NEXT FROM CUR_CARTON INTO @c_Sku, @c_LottableValue, @n_PackingQty
         
         WHILE @@FETCH_STATUS <> -1 --AND @n_continue IN(1,2)     
         BEGIN         	  
            SET @c_SQL = 'EXEC ' + @c_SPCode + ' @c_Pickslipno=@c_Pickslipno, @c_Storerkey=@c_Storerkey, @c_Sku=@c_Sku, @c_LottableValue=@c_LottableValue, 
                          @n_Cartonno=@n_Cartonno, @n_PackingQty=@n_PackingQty, @b_Success=@b_Success OUTPUT, @n_Err=@n_Err OUTPUT, @c_ErrMsg=@c_ErrMsg OUTPUT '
                          
            SET @c_ErrMsg2 = ''            
            SET @b_Success = 1  
              
            EXEC sp_executesql @c_SQL, 
                 N'@c_Pickslipno NVARCHAR(10), @c_Storerkey NVARCHAR(15), @c_Sku NVARCHAR(20), @c_LottableValue NVARCHAR(60), @n_CartonNo INT, @n_PackingQty INT, @b_Success INT OUTPUT, @n_Err INT OUTPUT, @c_ErrMsg NVARCHAR(250) OUTPUT', 
                 @c_Pickslipno,
                 @c_Storerkey,
                 @c_Sku,
                 @c_LottableValue, 
                 0, --@n_Cartonno
                 @n_PackingQty,
                 @b_Success OUTPUT,                      
                 @n_Err OUTPUT, 
                 @c_ErrMsg2 OUTPUT
                 
            IF @b_Success <> 1            
            BEGIN                         
            	  IF RTRIM(ISNULL(@c_errmsg,'')) = ''            	     
                	 SET @c_errmsg = RTRIM(ISNULL(@c_errmsg2,'')) 
                ELSE	 
            	     SET @c_errmsg = RTRIM(ISNULL(@c_errmsg,'')) + ' ' + CHAR(13) + RTRIM(ISNULL(@c_errmsg2,'')) 
            	     
                SELECT @n_continue = 3                    
            END                           
                          	  
            FETCH NEXT FROM CUR_CARTON INTO @c_Sku, @c_LottableValue, @n_PackingQty
         END
         CLOSE CUR_CARTON
         DEALLOCATE CUR_CARTON      	                          
      END      
   END
      
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN   	
        SELECT @n_NewCartonNo = ISNULL(MAX(Cartonno),0) + 1
        FROM PACKDETAIL (NOLOCK)
        WHERE Pickslipno = @c_Pickslipno
        
        SELECT @n_NewCartonNoFrom = @n_NewCartonNo
        
        SELECT Storerkey, LabelLine, Sku, Qty, Refno, RefNo2, DropID, UPC, ExpQty, LottableValue  
        INTO #TMP_PACKDETAIL
        FROM PACKDETAIL (NOLOCK)
        WHERE Pickslipno = @c_Pickslipno
        AND CartonNo = @n_FromCartonNo
        
        WHILE @n_cnt < @n_ToNumberOfCarton
        BEGIN
           EXECUTE isp_GenUCCLabelNo_Std
            @cPickslipNo = @c_PickSlipNo,          --(Wan01)
            @cLabelNo    = @c_NewLabelNo  OUTPUT,  --(Wan01)
            @b_success   = @b_success     OUTPUT,  --(Wan01)
            @n_err       = @n_err         OUTPUT,  --(Wan01)
            @c_errmsg    = @c_errmsg      OUTPUT   --(Wan01)
                           
           IF @b_success <> 1
           BEGIN
              SELECT @n_continue = 3
              SELECT @c_errmsg = 'isp_GenUCCLabelNo_Std ' + RTRIM(ISNULL(@c_errmsg,''))
            GOTO EXIT_SP 
           END        
         
          INSERT INTO PACKDETAIL (Pickslipno, Cartonno, Labelno, LabelLine, Storerkey, Sku, Qty, Refno, RefNo2, DropID, UPC, ExpQty, LottableValue)
          SELECT Pickslipno, 
                 @n_NewCartonNo, 
                 @c_NewLabelNo, 
                 LabelLine, 
                 Storerkey, 
                 Sku, 
                 Qty, 
                 Refno, 
                 RefNo2, 
                 DropID, 
                 UPC, 
                 ExpQty,
                 LottableValue  --NJOW01
           FROM PACKDETAIL (NOLOCK)
           WHERE Pickslipno = @c_Pickslipno
           AND CartonNo = @n_FromCartonNo

         IF @@ERROR <> 0 
         BEGIN
             SELECT @n_continue = 3 
             SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=61920   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
             SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Insert PackDetail Failed. (isp_DuplicateCarton)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(ISNULL(@c_errmsg,'')) + ' ) '
             GOTO EXIT_SP 
         END
         
         IF EXISTS (SELECT 1 FROM PACKINFO(NOLOCK) WHERE Pickslipno = @c_Pickslipno AND Cartonno = @n_NewCartonNo)         
         BEGIN
              DELETE FROM PACKINFO WHERE Pickslipno = @c_Pickslipno AND Cartonno = @n_NewCartonNo
         END

         INSERT INTO PACKINFO (Pickslipno, Cartonno, Weight, Cube, Qty, CartonType, Refno, TrackingNo)   --(Wan02)
         SELECT Pickslipno, 
                @n_NewCartonNo, 
                Weight, 
                Cube, 
                Qty, 
                CartonType, 
                Refno,
                TrackingNo                                                                               --(Wan02)
         FROM PACKINFO (NOLOCK)
         WHERE Pickslipno = @c_Pickslipno
         AND CartonNo = @n_FromCartonNo

         IF @@ERROR <> 0 
         BEGIN
             SELECT @n_continue = 3 
             SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=61930   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
             SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Insert PackInfo Failed. (isp_DuplicateCarton)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(ISNULL(@c_errmsg,'')) + ' ) '
             GOTO EXIT_SP 
         END                  
          
          SELECT @n_cnt = @n_cnt + 1
          SELECT @n_NewCartonNo = @n_NewCartonNo + 1
        END
        
        SELECT @n_NewCartonNoTo = @n_NewCartonNo - 1
   END
   
   EXIT_SP:

   IF @n_continue=3  -- Error Occured - Process And Return
   BEGIN
      SELECT @b_success = 0     
      IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_starttcnt 
      BEGIN
          ROLLBACK TRAN
      END
      ELSE BEGIN
          WHILE @@TRANCOUNT > @n_starttcnt 
          BEGIN
              COMMIT TRAN
          END          
      END
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'isp_DuplicateCarton'
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
      RETURN
   END
   ELSE 
   BEGIN
      SELECT @b_success = 1
      WHILE @@TRANCOUNT > @n_starttcnt 
      BEGIN
          COMMIT TRAN
      END
      RETURN
   END     
END 

GO