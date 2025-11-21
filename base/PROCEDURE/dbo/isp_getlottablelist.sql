SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: isp_GetLottableList                                */
/* Creation Date: 10-Aug-2016                                           */
/* Copyright: LFL                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: 373542 - Get Lottable 01-15 dropdown values.                */
/*          Exclude date lottable 4,5,13,14,15                          */
/*          Codelkup setting:                                           */
/*            listname - LOT<num>LIST. e.g. LOT07LIST                   */
/*            Code - Value for lottable dropdown                        */ 
/*            Description - Value Description                           */ 
/*            Short - Optional put 'SQL' to apply custom sql at notes   */ 
/*            Notes - Optional put custom script if short = SQL.        */
/*                    Must return two columns. Can apply two variables  */
/*                    for filtering which is @c_Storerkey and @c_sku    */
/*            Storerkey - Storer                                        */ 
/*            UDF01 - Sku Lottable Label                                */ 
/*            UDF02 - Y=Dropdown editable  N or Blank=Not editable      */ 
/*                                                                      */
/* Called By: lottable 01-15 dropdown datawindow)(dddw)                 */ 
/*            d_dddw_lottablelist (for lottable field                   */
/*            d_dddw_lottablelistpack (for packing by lottable)         */
/*                                                                      */
/* Parameters:                                                          */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver.  Purposes                                  */
/* 04-Jul-2019 NJOW01   1.0   WMS-9396 additional dropdown filtering    */
/*                            by pickislip, wave, load for packing by   */
/*                            lottable                                  */ 
/* 27-Jan-2021 Wan01    1.1   WMS-16079 - RG - LEGO - EXCEED Packing    */   
/************************************************************************/

CREATE PROCEDURE [dbo].[isp_GetLottableList] (
    @c_Storerkey NVARCHAR(15)
   ,@c_Sku NVARCHAR(20) 
   ,@c_LottableNum NVARCHAR(2)  -- lottable number 01 - 15
   ,@c_Datawindow NVARCHAR(50) = ''  --source datawindow
   ,@c_Pickslipno NVARCHAR(10) = ''  --optional only for pack by lottable
   ,@c_lottabledddwtype NVARCHAR(20) = '' --optional only for pack by lottable
)
AS
BEGIN 
   SET NOCOUNT ON
   SET ANSI_DEFAULTS OFF  
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_continue int,
           @n_cnt int,
           @n_starttcnt int,
           @b_success int,
           @n_err int,
           @c_errmsg nvarchar(250),
           @c_LottableLabel NVARCHAR(20),
           @c_SQL NVARCHAR(MAX),
           @c_SQLStatement NVARCHAR(MAX),
           @c_Wavekey NVARCHAR(10), 
           @c_Loadkey NVARCHAR(10),
           @c_Orderkey NVARCHAR(10)
           
         , @n_SPPosS          INT            = 0   --(Wan01)  
         , @n_SPPosE          INT            = 0   --(Wan01)          
         , @c_Option5         NVARCHAR(4000) = ''  --(Wan01)
         , @c_GetPKLAListSP   NVARCHAR(50)   = ''  --(Wan01)  
         , @c_PackByLottable  NVARCHAR(30)   = ''  --(Wan01)
         
         , @c_Facility        NVARCHAR(15)   = ''  --(Wan01)
         , @c_SQLParms        NVARCHAR(4000) = ''  --(Wan01)
                               
   SELECT @n_Continue = 1, @b_success = 1, @n_starttcnt = @@TRANCOUNT, @c_errmsg='', @n_err=0, @c_SQLStatement = ''
   
   --(Wan01) - START
   IF ISNULL(@c_lottabledddwtype,'') NOT IN ('')
   BEGIN
      SELECT @c_Orderkey = ph.OrderKey
            ,@c_Loadkey  = ph.LoadKey
      FROM PickHeader AS ph WITH (NOLOCK)
      WHERE ph.PickHeaderkey = @c_Pickslipno
   
      IF @c_Orderkey = ''
      BEGIN
         SELECT TOP 1 @c_Orderkey = lpd.OrderKey
         FROM LoadPlanDetail AS lpd WITH (NOLOCK)
         WHERE lpd.LoadKey = @c_Loadkey
      END
   
      IF @c_Orderkey <> ''
      BEGIN
         SELECT @c_Facility = oh.Facility
                     FROM ORDERS AS oh WITH (NOLOCK)
                     WHERE oh.OrderKey = @c_Orderkey
      END          
   
      SET @c_PackByLottable = ''
      EXEC nspGetRight
            @c_Facility   = @c_Facility  
         ,  @c_StorerKey  = @c_StorerKey 
         ,  @c_sku        = ''       
         ,  @c_ConfigKey  = 'PackByLottable' 
         ,  @b_Success    = @b_Success             OUTPUT
         ,  @c_authority  = @c_PackByLottable      OUTPUT 
         ,  @n_err        = @n_err                 OUTPUT
         ,  @c_errmsg     = @c_errmsg              OUTPUT
         ,  @c_Option5    = @c_Option5             OUTPUT

      IF @b_Success = 0 
      BEGIN
         SET @n_Continue = 3
         SET @n_err = 81010   
         SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Execu@c_errmsgting nspGetRight. (isp_GetLottableList)'   
         GOTO ENDPROC  
      END
 
      IF @c_PackByLottable = '1' AND @c_Option5 <> ''
      BEGIN
         SET @c_GetPKLAListSP = ''
         SELECT @c_GetPKLAListSP = dbo.fnc_GetParamValueFromString('@c_StoredProcName', @c_Option5, @c_GetPKLAListSP) 

         IF @c_GetPKLAListSP <> '' AND 
            EXISTS (SELECT 1 FROM sys.objects AS o (NOLOCK) WHERE SCHEMA_NAME(o.[schema_id]) = 'dbo' AND o.[name] = @c_GetPKLAListSP AND o.[type] = 'P')
         BEGIN
            SET @b_Success = 1
            SET @c_SQL = N'EXEC ' + @c_GetPKLAListSP
                       +'  @c_Storerkey   = @c_Storerkey'
                       +', @c_Sku         = @c_Sku'        
                       +', @c_LottableNum = @c_LottableNum' 
                       +', @c_Datawindow  = @c_Datawindow'  
                       +', @c_Pickslipno  = @c_Pickslipno'  
                       +', @c_lottabledddwtype = @c_lottabledddwtype'
                       +', @b_Success    = @b_Success OUTPUT'
                       +', @n_Err        = @n_Err     OUTPUT'
                       +', @c_ErrMsg     = @c_ErrMsg  OUTPUT'

            SET @c_SQLParms= N'@c_Storerkey        NVARCHAR(15)'
                           +', @c_Sku              NVARCHAR(20)'
                           +', @c_LottableNum      NVARCHAR(2)'
                           +', @c_Datawindow       NVARCHAR(50)'
                           +', @c_Pickslipno       NVARCHAR(10)'
                           +', @c_lottabledddwtype NVARCHAR(20)' 
                           +', @b_Success          INT          OUTPUT'
                           +', @n_Err              INT          OUTPUT'
                           +', @c_ErrMsg           NVARCHAR(255)OUTPUT'

            EXEC sp_ExecuteSQL  @c_SQL
                              , @c_SQLParms
                              , @c_Storerkey        
                              , @c_Sku              
                              , @c_LottableNum      
                              , @c_Datawindow       
                              , @c_Pickslipno       
                              , @c_lottabledddwtype 
                              , @b_Success      OUTPUT
                              , @n_Err          OUTPUT
                              , @c_ErrMsg       OUTPUT
                           
            IF @b_success = '2'
            BEGIN
               GOTO ENDPROC
            END
         END
      END
   END
   --(Wan01) - END
  
   IF ISNULL(@c_lottabledddwtype,'') IN ('','DROPDOWNBYCODELKUP') 
   BEGIN
      SET @c_SQL = N' SELECT @c_LottableLabel = Lottable' + @c_LottableNum  + 'Label ' +
                    ' FROM SKU (NOLOCK) 
                      WHERE Storerkey = @c_Storerkey 
                      AND Sku = @c_Sku ' 
      
      EXEC sp_executesql @c_SQL,
           N'@c_LottableLabel NVARCHAR(20) OUTPUT, @c_Storerkey NVARCHAR(15), @c_Sku NVARCHAR(20)', 
           @c_LottableLabel OUTPUT,
           @c_Storerkey,
           @c_Sku
      
      SELECT TOP 1 @c_SQLStatement = NOTES   
      FROM CODELKUP(NOLOCK)
      WHERE ListName = 'LOT' + @c_LottableNum + 'List'
      AND Storerkey = @c_Storerkey
      AND UDF01 = @c_LottableLabel
      AND ISNULL(UDF01,'') <> ''
      AND Short = 'SQL'
       
       IF ISNULL(@c_SQLStatement,'') <> ''
       BEGIN
         EXEC sp_executesql @c_SQLStatement,
              N'@c_Storerkey NVARCHAR(15), @c_Sku NVARCHAR(20)',            
              @c_Storerkey,
              @c_Sku      
              
         SELECT @n_err = @@ERROR
            IF @n_err <> 0
            BEGIN
                SELECT @n_continue = 3
                SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 50110   
                SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Execute Custom SQL Failed. (isp_GetLottableList)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) ' 
                GOTO ENDPROC
            END           
       END
       ELSE
       BEGIN    
          SELECT Code, Description
         FROM CODELKUP(NOLOCK)
         WHERE ListName = 'LOT' + @c_LottableNum + 'List'
         AND Storerkey = @c_Storerkey
         AND UDF01 = @c_LottableLabel
          AND ISNULL(UDF01,'') <> ''
         ORDER BY 1
      END
   END
   ELSE IF ISNULL(@c_lottabledddwtype,'') = 'DROPDOWNBYPICKSLIP'
   BEGIN    
      SELECT TOP 1 @c_Orderkey = O.Orderkey
       FROM PICKHEADER PH (NOLOCK)
       JOIN ORDERS O (NOLOCK) ON PH.Orderkey = O.Orderkey
       WHERE PH.Pickheaderkey = @c_Pickslipno
    
       IF ISNULL(@c_Orderkey,'') = ''
       BEGIN
          SELECT TOP 1 @c_Loadkey = LPD.Loadkey
          FROM PICKHEADER PH (NOLOCK)
          JOIN LOADPLANDETAIL LPD (NOLOCK) ON PH.Externorderkey = LPD.Loadkey
          WHERE PH.Pickheaderkey = @c_Pickslipno
          AND ISNULL(PH.Orderkey,'') = ''
       END
       
       IF ISNULL(@c_Orderkey,'') <> ''
       BEGIN
          SELECT DISTINCT 
                 CASE WHEN @c_LottableNum = '01' THEN LA.Lottable01
                      WHEN @c_LottableNum = '02' THEN LA.Lottable02  
                      WHEN @c_LottableNum = '03' THEN LA.Lottable03  
                      WHEN @c_LottableNum = '04' THEN CONVERT(NVARCHAR,LA.Lottable04,121)  
                      WHEN @c_LottableNum = '05' THEN CONVERT(NVARCHAR,LA.Lottable05,121)  
                      WHEN @c_LottableNum = '06' THEN LA.Lottable06  
                      WHEN @c_LottableNum = '07' THEN LA.Lottable07  
                      WHEN @c_LottableNum = '08' THEN LA.Lottable08  
                      WHEN @c_LottableNum = '09' THEN LA.Lottable09  
                      WHEN @c_LottableNum = '10' THEN LA.Lottable10  
                      WHEN @c_LottableNum = '11' THEN LA.Lottable11  
                      WHEN @c_LottableNum = '12' THEN LA.Lottable12  
                      WHEN @c_LottableNum = '13' THEN CONVERT(NVARCHAR,LA.Lottable13,121)  
                      WHEN @c_LottableNum = '14' THEN CONVERT(NVARCHAR,LA.Lottable14,121)  
                      WHEN @c_LottableNum = '15' THEN CONVERT(NVARCHAR,LA.Lottable15,121)
                  END AS Code,
                  '' AS Description
          FROM PICKDETAIL PD (NOLOCK) 
          JOIN LOTATTRIBUTE LA (NOLOCK) ON PD.Lot = LA.Lot
          WHERE PD.Orderkey = @c_Orderkey
          AND PD.Sku = @c_Sku
       END
       ELSE IF ISNULL(@c_Loadkey,'') <> ''
       BEGIN
          SELECT DISTINCT 
                 CASE WHEN @c_LottableNum = '01' THEN LA.Lottable01
                      WHEN @c_LottableNum = '02' THEN LA.Lottable02  
                      WHEN @c_LottableNum = '03' THEN LA.Lottable03  
                      WHEN @c_LottableNum = '04' THEN CONVERT(NVARCHAR,LA.Lottable04,121)  
                      WHEN @c_LottableNum = '05' THEN CONVERT(NVARCHAR,LA.Lottable05,121)  
                      WHEN @c_LottableNum = '06' THEN LA.Lottable06  
                      WHEN @c_LottableNum = '07' THEN LA.Lottable07  
                      WHEN @c_LottableNum = '08' THEN LA.Lottable08  
                      WHEN @c_LottableNum = '09' THEN LA.Lottable09  
                      WHEN @c_LottableNum = '10' THEN LA.Lottable10  
                      WHEN @c_LottableNum = '11' THEN LA.Lottable11  
                      WHEN @c_LottableNum = '12' THEN LA.Lottable12  
                      WHEN @c_LottableNum = '13' THEN CONVERT(NVARCHAR,LA.Lottable13,121)  
                      WHEN @c_LottableNum = '14' THEN CONVERT(NVARCHAR,LA.Lottable14,121)  
                      WHEN @c_LottableNum = '15' THEN CONVERT(NVARCHAR,LA.Lottable15,121)
                  END AS Code,
                  '' AS Description
          FROM LOADPLANDETAIL LPD (NOLOCK)
          JOIN PICKDETAIL PD (NOLOCK) ON LPD.Orderkey = PD.Orderkey
          JOIN LOTATTRIBUTE LA (NOLOCK) ON PD.Lot = LA.Lot
          WHERE LPD.Loadkey = @c_Loadkey         
          AND PD.Sku = @c_Sku        
       END      
       ELSE
       BEGIN
           SELECT Code, Description
         FROM CODELKUP(NOLOCK)
         WHERE 1=2
      END                  
   END
   ELSE IF ISNULL(@c_lottabledddwtype,'') = 'DROPDOWNBYLOAD'
   BEGIN
      SELECT TOP 1 @c_Loadkey = LPD.Loadkey
       FROM PICKHEADER PH (NOLOCK)
       JOIN ORDERS O (NOLOCK) ON PH.Orderkey = O.Orderkey
       JOIN LOADPLANDETAIL LPD (NOLOCK) ON O.Orderkey = LPD.Orderkey
       WHERE PH.Pickheaderkey = @c_Pickslipno
    
       IF ISNULL(@c_Loadkey,'') = ''
       BEGIN
          SELECT TOP 1 @c_Loadkey = LPD.Loadkey
          FROM PICKHEADER PH (NOLOCK)
          JOIN LOADPLANDETAIL LPD (NOLOCK) ON PH.Externorderkey = LPD.Loadkey
          WHERE PH.Pickheaderkey = @c_Pickslipno
          AND ISNULL(PH.Orderkey,'') = ''
       END
       
       IF ISNULL(@c_Loadkey,'') <> ''
       BEGIN
          SELECT DISTINCT 
                 CASE WHEN @c_LottableNum = '01' THEN LA.Lottable01
                      WHEN @c_LottableNum = '02' THEN LA.Lottable02  
                      WHEN @c_LottableNum = '03' THEN LA.Lottable03  
                      WHEN @c_LottableNum = '04' THEN CONVERT(NVARCHAR,LA.Lottable04,121)  
                      WHEN @c_LottableNum = '05' THEN CONVERT(NVARCHAR,LA.Lottable05,121)  
                      WHEN @c_LottableNum = '06' THEN LA.Lottable06  
                      WHEN @c_LottableNum = '07' THEN LA.Lottable07  
                      WHEN @c_LottableNum = '08' THEN LA.Lottable08  
                      WHEN @c_LottableNum = '09' THEN LA.Lottable09  
                      WHEN @c_LottableNum = '10' THEN LA.Lottable10  
                      WHEN @c_LottableNum = '11' THEN LA.Lottable11  
                      WHEN @c_LottableNum = '12' THEN LA.Lottable12  
                      WHEN @c_LottableNum = '13' THEN CONVERT(NVARCHAR,LA.Lottable13,121)  
                      WHEN @c_LottableNum = '14' THEN CONVERT(NVARCHAR,LA.Lottable14,121)  
                      WHEN @c_LottableNum = '15' THEN CONVERT(NVARCHAR,LA.Lottable15,121)
                  END AS Code,
                  '' AS Description
          FROM LOADPLANDETAIL LPD (NOLOCK)
          JOIN PICKDETAIL PD (NOLOCK) ON LPD.Orderkey = PD.Orderkey
          JOIN LOTATTRIBUTE LA (NOLOCK) ON PD.Lot = LA.Lot
          WHERE LPD.Loadkey = @c_Loadkey         
          AND PD.Sku = @c_Sku        
       END      
       ELSE
       BEGIN
           SELECT Code, Description
         FROM CODELKUP(NOLOCK)
         WHERE 1=2
      END            
   END
   ELSE IF ISNULL(@c_lottabledddwtype,'') = 'DROPDOWNBYWAVE'
   BEGIN
      SELECT TOP 1 @c_Wavekey = WD.Wavekey
       FROM PICKHEADER PH (NOLOCK)
       JOIN ORDERS O (NOLOCK) ON PH.Orderkey = O.Orderkey
       JOIN WAVEDETAIL WD (NOLOCK) ON O.Orderkey = WD.Orderkey
       WHERE PH.Pickheaderkey = @c_Pickslipno
    
       IF ISNULL(@c_Wavekey,'') = ''
       BEGIN
          SELECT TOP 1 @c_Wavekey = WD.Wavekey
          FROM PICKHEADER PH (NOLOCK)
          JOIN LOADPLANDETAIL LPD (NOLOCK) ON PH.Externorderkey = LPD.Loadkey
          JOIN WAVEDETAIL WD (NOLOCK) ON LPD.Orderkey = WD.Orderkey
          WHERE PH.Pickheaderkey = @c_Pickslipno
          AND ISNULL(PH.Orderkey,'') = ''
       END
       
       IF ISNULL(@c_Wavekey,'') <> ''
       BEGIN
          SELECT DISTINCT 
                 CASE WHEN @c_LottableNum = '01' THEN LA.Lottable01
                      WHEN @c_LottableNum = '02' THEN LA.Lottable02  
                      WHEN @c_LottableNum = '03' THEN LA.Lottable03  
                      WHEN @c_LottableNum = '04' THEN CONVERT(NVARCHAR,LA.Lottable04,121)  
                      WHEN @c_LottableNum = '05' THEN CONVERT(NVARCHAR,LA.Lottable05,121)  
                      WHEN @c_LottableNum = '06' THEN LA.Lottable06  
                      WHEN @c_LottableNum = '07' THEN LA.Lottable07  
                      WHEN @c_LottableNum = '08' THEN LA.Lottable08  
                      WHEN @c_LottableNum = '09' THEN LA.Lottable09  
                      WHEN @c_LottableNum = '10' THEN LA.Lottable10  
                      WHEN @c_LottableNum = '11' THEN LA.Lottable11  
                      WHEN @c_LottableNum = '12' THEN LA.Lottable12  
                      WHEN @c_LottableNum = '13' THEN CONVERT(NVARCHAR,LA.Lottable13,121)  
                      WHEN @c_LottableNum = '14' THEN CONVERT(NVARCHAR,LA.Lottable14,121)  
                      WHEN @c_LottableNum = '15' THEN CONVERT(NVARCHAR,LA.Lottable15,121)
                  END AS Code,
                  '' AS Description
          FROM WAVEDETAIL WD (NOLOCK)
          JOIN PICKDETAIL PD (NOLOCK) ON WD.Orderkey = PD.Orderkey
          JOIN LOTATTRIBUTE LA (NOLOCK) ON PD.Lot = LA.Lot
          WHERE WD.Wavekey = @c_Wavekey          
          AND PD.Sku = @c_Sku
       END      
       ELSE
       BEGIN
           SELECT Code, Description
         FROM CODELKUP(NOLOCK)
         WHERE 1=2
     END     
   END
   ELSE
   BEGIN
      SELECT Code, Description
      FROM CODELKUP(NOLOCK)
      WHERE 1=2
   END 
   
 ENDPROC: 
 
   IF @n_continue=3  -- Error Occured - Process And Return
   BEGIN
      SELECT @b_success = 0
      IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_starttcnt
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
      execute nsp_logerror @n_err, @c_errmsg, 'isp_GetLottableList'
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
END -- End PROC

GO