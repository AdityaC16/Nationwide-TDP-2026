/api/spend
    -- GET attr: 
        spend_cat, spend_id, spend_month, spend_amount
        (if empty, retrun all spends for customer)
    -- POST 
        attr: spend_cat, spend_id (autogen), spend_month, spend_amount
    -- DELETE
        attr: spend_id
    -- PATCH (later)