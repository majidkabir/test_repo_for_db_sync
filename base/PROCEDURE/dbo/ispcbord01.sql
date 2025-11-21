SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: ispCBORD01                                         */
/* Creation Date: 02-09-2014                                            */
/* Copyright: LF Logistics                                              */
/* Written by: Shong                                                    */
/*                                                                      */
/* Purpose: SOS#320025-BeBe - Pack Confirmation by Loadplan             */
/*                                                                      */
/* Called By: PB object - n_cst_order EVENT ue_combineorder             */
/*                                                                      */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author     Purposes                                     */
/************************************************************************/
CREATE PROCEDURE [dbo].[ispCBORD01]
   @c_FromOrderKey  NVARCHAR(10)
,  @c_ToOrderKey    NVARCHAR(10)
,  @b_Success       INT       OUTPUT
,  @n_Err           INT       OUTPUT
,  @c_ErrMsg        NVARCHAR(250)   OUTPUT 
AS  
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE 
      @n_Starttcnt INT,
      @n_Continue  INT,
      @b_Debug     INT

   DECLARE 
      @c_FromFacility      NVARCHAR(5),
      @c_ToFacility        NVARCHAR(5),
      @c_FromStorer        NVARCHAR(15),
      @c_ToStorer          NVARCHAR(15), 
      @c_FromOrdLineNo    NVARCHAR(5),
      @n_MaxToOrdLineNo   INT,
      @c_MaxToOrdLineNo   NVARCHAR(5),
      @c_NewToOrdLineNo   NVARCHAR(5)

   DECLARE 
      @n_RecordCnt       INT

   SELECT 
      @b_Success = 0,
      @n_Continue = 1,
      @n_Starttcnt = @@TRANCOUNT,
      @b_Debug = 0


   DECLARE @c_FromOrderStatus NVARCHAR(10),
           @c_ToOrderStatus   NVARCHAR(10)

   SET @c_FromOrderStatus = ''
   SET @c_ToOrderStatus   = ''
   SET @c_FromFacility = ''
   SET @c_ToFacility = ''
   SET @c_FromStorer = ''
   SET @c_ToStorer = ''
   
   SELECT @c_FromOrderStatus = [Status],
          @c_FromFacility = Facility, 
          @c_FromStorer   = StorerKey   
   FROM ORDERS (NOLOCK) 
   WHERE OrderKey = @c_FromOrderKey
   
   SELECT @c_ToOrderStatus = [Status],
          @c_ToFacility = Facility, 
          @c_ToStorer   = StorerKey
   FROM ORDERS (NOLOCK) 
   WHERE OrderKey = @c_ToOrderKey  

                   
   -- Validate FromLoad and ToLoad
   IF ISNULL(RTRIM(@c_FromOrderStatus),'')=''
   BEGIN
      SELECT @n_Continue = 3
      SELECT @n_Err = 65001
      SELECT @c_Errmsg = 'NSQL'+CONVERT(CHAR(5), @n_Err)+': OrderKey Not Found ' + RTRIM(@c_FromOrderKey) + ' (ispCBORD01)'
      GOTO QUIT
   END
   IF ISNULL(RTRIM(@c_ToOrderStatus),'')='' 
   BEGIN
      SELECT @n_Continue = 3
      SELECT @n_Err = 65002
      SELECT @c_Errmsg = 'NSQL'+CONVERT(CHAR(5), @n_Err)+': OrderKey Not Found ' + RTRIM(@c_ToOrderKey) + ' (ispCBORD01)'
      GOTO QUIT
   END

   IF (@c_FromOrderStatus <> '0') OR (@c_FromOrderStatus = 'CANC')
   BEGIN
      SELECT @n_Continue = 3
      SELECT @n_Err = 65003
      SELECT @c_Errmsg = 'NSQL'+CONVERT(CHAR(5), @n_Err)+': Cannot combine with ' +
             CASE @c_FromOrderStatus
                  WHEN '1' THEN 'Allocated'
                  WHEN '2' THEN 'Allocated'
                  WHEN '3' THEN 'Pick In Progress'
                  WHEN '5' THEN 'Picked'
                  WHEN '9' THEN 'Shipped' 
                  WHEN 'CANC' THEN 'Cancelled'
                  ELSE  @c_FromOrderStatus
              END +     
             ' Order ' + RTRIM(@c_FromOrderKey) + ' (ispCBORD01)'
      GOTO QUIT
   END

   IF (@c_ToOrderStatus BETWEEN '3' AND '9') OR (@c_ToOrderStatus = 'CANC')
   BEGIN
      SELECT @n_Continue = 3
      SELECT @n_Err = 65004
      SELECT @c_Errmsg = 'NSQL'+CONVERT(CHAR(5), @n_Err)+': Cannot combine with ' +
             CASE @c_ToOrderStatus
                  WHEN '1' THEN 'Allocated'
                  WHEN '2' THEN 'Allocated'
                  WHEN '3' THEN 'Pick In Progress'
                  WHEN '5' THEN 'Picked'
                  WHEN '9' THEN 'Shipped'
                  WHEN 'CANC' THEN 'Cancelled'                   
                  ELSE  @c_ToOrderStatus
              END + 
              ' Order ' + RTRIM(@c_ToOrderKey) + ' (ispCBORD01)'
      GOTO QUIT
   END
   IF EXISTS(SELECT 1 FROM PICKDETAIL WITH (NOLOCK) 
             WHERE OrderKey = @c_FromOrderKey)
   BEGIN
      SELECT @n_Continue = 3
      SELECT @n_Err = 65005
      SELECT @c_Errmsg = 'NSQL'+CONVERT(CHAR(5), @n_Err)+': Orders was Allocated. Key= ' + RTRIM(@c_FromOrderKey) + ' (ispCBORD01)'
      GOTO QUIT      
   END

   IF @b_Debug = 1
      SELECT @c_FromFacility '@c_FromFacility', @c_ToFacility '@c_ToFacility'

   IF @c_FromFacility <> @c_ToFacility
   BEGIN
      SELECT @n_Continue = 3
      SELECT @n_Err = 65006
      SELECT @c_Errmsg = 'NSQL'+CONVERT(CHAR(5), @n_Err)+': Cannot combine loads from different facility. (ispCBORD01)'
      GOTO QUIT
   END      
   IF @c_FromStorer <> @c_ToStorer
   BEGIN
      SELECT @n_Continue = 3
      SELECT @n_Err = 65007
      SELECT @c_Errmsg = 'NSQL'+CONVERT(CHAR(5), @n_Err)+': Cannot combine loads from different Storer. (ispCBORD01)'
      GOTO QUIT
   END      
   IF EXISTS(SELECT 1 FROM LoadplanDetail WITH (NOLOCK) 
             WHERE OrderKey = @c_FromOrderKey)
   BEGIN
      SELECT @n_Continue = 3
      SELECT @n_Err = 65008
      SELECT @c_Errmsg = 'NSQL'+CONVERT(CHAR(5), @n_Err)+': Order ' + RTRIM(@c_FromOrderKey) + ' Already Populated to Load Plan (ispCBORD01)'
      GOTO QUIT      
   END
   IF EXISTS(SELECT 1 FROM WaveDetail WITH (NOLOCK) 
             WHERE OrderKey = @c_FromOrderKey)
   BEGIN
      SELECT @n_Continue = 3
      SELECT @n_Err = 65009
      SELECT @c_Errmsg = 'NSQL'+CONVERT(CHAR(5), @n_Err)+': Order ' + RTRIM(@c_FromOrderKey) + ' Already Populated to Wave (ispCBORD01)'
      GOTO QUIT      
   END
   IF EXISTS(SELECT 1 FROM MBOLDETAIL WITH (NOLOCK) 
             WHERE OrderKey = @c_FromOrderKey)
   BEGIN
      SELECT @n_Continue = 3
      SELECT @n_Err = 65010
      SELECT @c_Errmsg = 'NSQL'+CONVERT(CHAR(5), @n_Err)+': Order ' + RTRIM(@c_FromOrderKey) + ' Already Populated to MBOL (ispCBORD01)'
      GOTO QUIT      
   END
   IF EXISTS(SELECT 1 FROM PickHeader WITH (NOLOCK) 
             WHERE OrderKey = @c_FromOrderKey)
   BEGIN
      SELECT @n_Continue = 3
      SELECT @n_Err = 65011
      SELECT @c_Errmsg = 'NSQL'+CONVERT(CHAR(5), @n_Err)+': Order ' + RTRIM(@c_FromOrderKey) + ' Pick Slip Already Printed (ispCBORD01)'
      GOTO QUIT      
   END
      
   BEGIN TRAN
     
   IF (@n_Continue = 1 OR @n_Continue = 2) -- Perform Updates
   BEGIN
      SELECT 
         @c_FromOrdLineNo       = '',
         @n_MaxToOrdLineNo      = 0,
         @c_MaxToOrdLineNo      = '',
         @c_NewToOrdLineNo     = ''
         
      SELECT @c_MaxToOrdLineNo = MAX(OrderLineNumber)
      FROM   ORDERDETAIL WITH (NOLOCK)
      WHERE  OrderKey = @c_ToOrderKey          
      
      IF ISNUMERIC(@c_MaxToOrdLineNo) = 1
      BEGIN
         SET @n_MaxToOrdLineNo = CAST(@c_MaxToOrdLineNo AS INT)
      END
      ELSE
      BEGIN
         SELECT @n_Continue = 3
         SELECT @n_Err = 65012
         SELECT @c_Errmsg = 'NSQL'+CONVERT(CHAR(5), @n_Err)+': Order Line Is not Numeric. (ispCBORD01)'
         GOTO QUIT      
      END         

      -- Loop thru each FromLoad detail lines, update detail lines
      DECLARE ORDERDET_CUR CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT OrderLineNumber
      FROM   ORDERDETAIL WITH (NOLOCK)
      WHERE  OrderKey = @c_FromOrderKey
      ORDER BY OrderLineNumber
      
      OPEN ORDERDET_CUR
   
      FETCH NEXT FROM ORDERDET_CUR INTO @c_FromOrdLineNo
   
      WHILE @@FETCH_STATUS <> -1 AND (@n_Continue = 1 OR @n_Continue = 2)
      BEGIN
         -- Increase LineNo by 1
         SELECT @n_MaxToOrdLineNo = @n_MaxToOrdLineNo + 1
         SELECT @c_NewToOrdLineNo = RIGHT(REPLICATE('0', 5) + RTRIM(CONVERT(CHAR(5), @n_MaxToOrdLineNo)), 5)
         
         IF @b_Debug = 1
            SELECT @c_NewToOrdLineNo '@c_NewToOrdLineNo'

         UPDATE ORDERDETAIL WITH (ROWLOCK)
         SET   OrderKey        = @c_ToOrderKey,
               OrderLineNumber = @c_NewToOrdLineNo, 
               ExternConsoOrderKey = @c_FromOrderKey,
               ConsoOrderLineNo = @c_FromOrdLineNo, 
               EditWho         = sUser_sName(),
               EditDate        = GetDate(),
               TrafficCop      = NULL
         WHERE OrderKey        = @c_FromOrderKey
         AND   OrderLineNumber = @c_FromOrdLineNo

         SELECT @n_Err = @@ERROR
         IF @n_Err <> 0
         BEGIN
            SELECT @n_Continue = 3
            SELECT @n_Err = 65013
            SELECT @c_Errmsg = 'NSQL'+CONVERT(CHAR(5), @n_Err)+': Update Failed On Table ORDERDETAIL. (ispCBORD01)'
         END

         FETCH NEXT FROM ORDERDET_CUR INTO @c_FromOrdLineNo
      END
      CLOSE ORDERDET_CUR
      DEALLOCATE ORDERDET_CUR
      
      SET @n_RecordCnt = 0 
      SELECT @n_RecordCnt = COUNT(*)
      FROM   ORDERDETAIL WITH (NOLOCK)
      WHERE  OrderKey = @c_FromOrderKey

      IF @n_RecordCnt > 0 
      BEGIN
         SELECT @n_Continue = 3
         SELECT @n_Err = 65014
         SELECT @c_Errmsg = 'NSQL'+CONVERT(CHAR(5), @n_Err)+': Combine Order Failed. (ispCBORD01)'
         GOTO QUIT           
      END

      --(Wan01) - Canc fromorderkey
      UPDATE ORDERS WITH (ROWLOCK)
      SET   Status    = 'CANC',
            SOStatus  = 'CANC',
            EditWho   = sUser_sName(),
            EditDate  = GetDate(),
            Trafficcop= NULL
      WHERE OrderKey  = @c_FromOrderKey 


      SET @n_Err = @@ERROR
      IF @n_Err <> 0
      BEGIN
         SET @n_Continue = 3
         SET @n_Err = 65015
         SET @c_Errmsg = 'NSQL'+CONVERT(CHAR(5), @n_Err)+': Update Failed On Table ORDERDETAIL. (ispCBORD01)'
         GOTO QUIT  
      END
      --(Wan01) - Canc fromorderkey
   END 
   
   QUIT:
   -- Error Occured - Process And Return
   IF @n_Continue=3
   BEGIN
      --(Wan01) - START
      SET @b_Success = 0    
      IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCnt    
      BEGIN    
         ROLLBACK TRAN    
      END  
      ELSE
      BEGIN
         WHILE @@TRANCOUNT > @n_StartTCnt
         BEGIN
            COMMIT TRAN
         END
      END  
      --(Wan01) - END

      EXECUTE nsp_LogError @n_Err, @c_ErrMsg, 'ispCBORD01'
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
      RETURN
   END
   ELSE
   BEGIN
      --(Wan01) - START
      SET @b_Success = 1    
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END

      --(Wan01) - END
      RETURN
   END
END

GO